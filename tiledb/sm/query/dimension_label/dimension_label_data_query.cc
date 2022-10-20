/**
 * @file dimension_label_query.cc
 *
 * @section LICENSE
 *
 * The MIT License
 *
 * @copyright Copyright (c) 2022 TileDB, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * @section DESCRIPTION
 *
 * Classes for querying (reading/writing) a dimension label using the index
 * dimension for setting the subarray.
 */

#include "tiledb/sm/query/dimension_label/dimension_label_data_query.h"
#include "tiledb/common/common.h"
#include "tiledb/common/unreachable.h"
#include "tiledb/sm/dimension_label/dimension_label.h"
#include "tiledb/sm/enums/query_status.h"
#include "tiledb/sm/query/dimension_label/index_data.h"
#include "tiledb/sm/query/query.h"
#include "tiledb/sm/query/query_buffer.h"
#include "tiledb/sm/subarray/subarray.h"

#include <algorithm>
#include <functional>

using namespace tiledb::common;

namespace tiledb::sm {

DimensionLabelReadDataQuery::DimensionLabelReadDataQuery(
    StorageManager* storage_manager,
    DimensionLabel* dimension_label,
    const Subarray& parent_subarray,
    const QueryBuffer& label_buffer,
    const uint32_t dim_idx)
    : query_{tdb_unique_ptr<Query>(tdb_new(
          Query, storage_manager, dimension_label->indexed_array(), nullopt))} {
  // Set the layout (ordered, 1D).
  throw_if_not_ok(query_->set_layout(Layout::ROW_MAJOR));

  // Set the subarray if it has index ranges added to it.
  if (!parent_subarray.is_default(dim_idx) &&
      !parent_subarray.has_label_ranges(dim_idx)) {
    Subarray subarray{*query_->subarray()};
    throw_if_not_ok(subarray.set_ranges_for_dim(
        0, parent_subarray.ranges_for_dim(dim_idx)));
    throw_if_not_ok(query_->set_subarray(subarray));
  }

  // Set the label data buffer.
  query_->set_dimension_label_buffer(
      dimension_label->label_attribute()->name(), label_buffer);
}

void DimensionLabelReadDataQuery::add_index_ranges_from_label(
    const bool is_point_ranges, const void* start, const uint64_t count) {
  Subarray subarray{*query_->subarray()};
  subarray.add_index_ranges_from_label(0, is_point_ranges, start, count);
  throw_if_not_ok(query_->set_subarray(subarray));
}

bool DimensionLabelReadDataQuery::completed() const {
  return query_->status() == QueryStatus::COMPLETED;
}

void DimensionLabelReadDataQuery::process() {
  throw_if_not_ok(query_->init());
  throw_if_not_ok(query_->process());
}

/**
 * Typed implementation to check if data is sorted.
 *
 * TODO: This is a quick-and-dirty implementation while we decide where
 * sorting is handled for ordered dimension labels. If we keep this design,
 * we should consider optimizing (parallelizing?) the loops in this check.
 *
 * @param buffer Buffer to check for sort.
 * @param buffer_size Total size of the buffer.
 * @param increasing If ``true`` check if the data is stricly increasing. If
 *     ``false``, check if the data is strictly decreasing.
 */
template <
    typename T,
    typename std::enable_if<std::is_arithmetic<T>::value>::type* = nullptr>
bool is_sorted_buffer_impl(
    stats::Stats* stats,
    const T* buffer,
    const uint64_t* buffer_size,
    bool increasing) {
  auto timer_se = stats->start_timer("check_data_sort");
  uint64_t num_values = *buffer_size / sizeof(T);
  if (increasing) {
    for (uint64_t index{0}; index < num_values - 1; ++index) {
      if (buffer[index + 1] <= buffer[index]) {
        return false;
      }
    }
  } else {
    for (uint64_t index{0}; index < num_values - 1; ++index) {
      if (buffer[index + 1] >= buffer[index]) {
        return false;
      }
    }
  }
  return true;
}

/**
 * Checks if the input buffer is sorted.
 *
 * @param buffer Buffer to check for sort.
 * @param type Datatype of the input buffer.
 * @param increasing If ``true`` check if the data is strictly increasing. If
 *     ``false``, check if the data is strictly decreasing.
 */
bool is_sorted_buffer(
    stats::Stats* stats,
    const QueryBuffer& buffer,
    const Datatype type,
    bool increasing) {
  switch (type) {
    case Datatype::INT8:
      return is_sorted_buffer_impl<int8_t>(
          stats,
          buffer.typed_buffer<int8_t>(),
          buffer.buffer_size_,
          increasing);
    case Datatype::UINT8:
      return is_sorted_buffer_impl<uint8_t>(
          stats,
          buffer.typed_buffer<uint8_t>(),
          buffer.buffer_size_,
          increasing);
    case Datatype::INT16:
      return is_sorted_buffer_impl<int16_t>(
          stats,
          buffer.typed_buffer<int16_t>(),
          buffer.buffer_size_,
          increasing);
    case Datatype::UINT16:
      return is_sorted_buffer_impl<uint16_t>(
          stats,
          buffer.typed_buffer<uint16_t>(),
          buffer.buffer_size_,
          increasing);
    case Datatype::INT32:
      return is_sorted_buffer_impl<int32_t>(
          stats,
          buffer.typed_buffer<int32_t>(),
          buffer.buffer_size_,
          increasing);
    case Datatype::UINT32:
      return is_sorted_buffer_impl<uint32_t>(
          stats,
          buffer.typed_buffer<uint32_t>(),
          buffer.buffer_size_,
          increasing);
    case Datatype::INT64:
      return is_sorted_buffer_impl<int64_t>(
          stats,
          buffer.typed_buffer<int64_t>(),
          buffer.buffer_size_,
          increasing);
    case Datatype::UINT64:
      return is_sorted_buffer_impl<uint64_t>(
          stats,
          buffer.typed_buffer<uint64_t>(),
          buffer.buffer_size_,
          increasing);
    case Datatype::FLOAT32:
      return is_sorted_buffer_impl<float>(
          stats, buffer.typed_buffer<float>(), buffer.buffer_size_, increasing);
    case Datatype::FLOAT64:
      return is_sorted_buffer_impl<double>(
          stats,
          buffer.typed_buffer<double>(),
          buffer.buffer_size_,
          increasing);
    case Datatype::DATETIME_YEAR:
    case Datatype::DATETIME_MONTH:
    case Datatype::DATETIME_WEEK:
    case Datatype::DATETIME_DAY:
    case Datatype::DATETIME_HR:
    case Datatype::DATETIME_MIN:
    case Datatype::DATETIME_SEC:
    case Datatype::DATETIME_MS:
    case Datatype::DATETIME_US:
    case Datatype::DATETIME_NS:
    case Datatype::DATETIME_PS:
    case Datatype::DATETIME_FS:
    case Datatype::DATETIME_AS:
    case Datatype::TIME_HR:
    case Datatype::TIME_MIN:
    case Datatype::TIME_SEC:
    case Datatype::TIME_MS:
    case Datatype::TIME_US:
    case Datatype::TIME_NS:
    case Datatype::TIME_PS:
    case Datatype::TIME_FS:
    case Datatype::TIME_AS:
      return is_sorted_buffer_impl<int64_t>(
          stats,
          buffer.typed_buffer<int64_t>(),
          buffer.buffer_size_,
          increasing);
    default:
      stdx::unreachable();
  }

  return true;
}

OrderedWriteDataQuery::OrderedWriteDataQuery(
    StorageManager* storage_manager,
    stats::Stats* stats,
    DimensionLabel* dimension_label,
    const Subarray& parent_subarray,
    const QueryBuffer& label_buffer,
    const QueryBuffer& index_buffer,
    const uint32_t dim_idx,
    optional<std::string> fragment_name)
    : stats_{stats}
    , query_{tdb_unique_ptr<Query>(tdb_new(
          Query,
          storage_manager,
          dimension_label->indexed_array(),
          fragment_name))} {
  // Set query layout.
  throw_if_not_ok(query_->set_layout(Layout::ROW_MAJOR));

  // Verify the label data is sorted in the correct order and set label buffer.
  if (!is_sorted_buffer(
          stats_,
          label_buffer,
          dimension_label->label_dimension()->type(),
          dimension_label->label_order() == LabelOrder::INCREASING_LABELS)) {
    throw DimensionLabelDataQueryStatusException(
        "Failed to create dimension label query. The label data is not in the "
        "expected order.");
  }
  query_->set_dimension_label_buffer(
      dimension_label->label_attribute()->name(), label_buffer);

  // Set the subarray.
  if (index_buffer.buffer_ == nullptr) {
    // Set the subarray if it has index ranges added to it.
    if (!parent_subarray.is_default(dim_idx)) {
      Subarray subarray{*query_->subarray()};
      throw_if_not_ok(subarray.set_ranges_for_dim(
          0, parent_subarray.ranges_for_dim(dim_idx)));
      throw_if_not_ok(query_->set_subarray(subarray));
    }

  } else {
    // Set the subarray using the points from the index buffer.
    uint64_t count = *index_buffer.buffer_size_ /
                     datatype_size(dimension_label->index_dimension()->type());
    Subarray subarray{*query_->subarray()};
    throw_if_not_ok(subarray.set_coalesce_ranges(true));
    throw_if_not_ok(subarray.add_point_ranges(0, index_buffer.buffer_, count));
    throw_if_not_ok(query_->set_subarray(subarray));
  }
}

bool OrderedWriteDataQuery::completed() const {
  return query_->status() == QueryStatus::COMPLETED;
}

void OrderedWriteDataQuery::process() {
  throw_if_not_ok(query_->init());
  throw_if_not_ok(query_->process());
}

void OrderedWriteDataQuery::add_index_ranges_from_label(
    const bool, const void*, const uint64_t) {
  throw DimensionLabelDataQueryStatusException(
      "Updating index ranges is not supported on writes.");
}

UnorderedWriteDataQuery::UnorderedWriteDataQuery(
    StorageManager* storage_manager,
    DimensionLabel* dimension_label,
    const Subarray& parent_subarray,
    const QueryBuffer& label_buffer,
    const QueryBuffer& index_buffer,
    const uint32_t dim_idx,
    optional<std::string> fragment_name)
    : indexed_array_query_{tdb_unique_ptr<Query>(tdb_new(
          Query,
          storage_manager,
          dimension_label->indexed_array(),
          fragment_name))}
    , labelled_array_query_{tdb_unique_ptr<Query>(tdb_new(
          Query,
          storage_manager,
          dimension_label->labelled_array(),
          fragment_name))} {
  // Create locally stored index data if the index buffer is empty.
  bool use_local_index = index_buffer.buffer_ == nullptr;
  if (use_local_index) {
    // Check only one range on the subarray is set.
    if (!parent_subarray.is_default(dim_idx)) {
      const auto& ranges = parent_subarray.ranges_for_dim(dim_idx);
      if (ranges.size() != 1) {
        throw DimensionLabelDataQueryStatusException(
            "Failed to create dimension label query. Dimension label writes "
            "can only be set for a single range.");
      }
    }

    // Create the index data.
    index_data_ = tdb_unique_ptr<IndexData>(IndexDataCreate::make_index_data(
        dimension_label->index_dimension()->type(),
        parent_subarray.ranges_for_dim(dim_idx)[0]));
  }

  // Set-up labelled array (sparse array).
  throw_if_not_ok(labelled_array_query_->set_layout(Layout::UNORDERED));
  labelled_array_query_->set_dimension_label_buffer(
      dimension_label->label_dimension()->name(), label_buffer);
  if (use_local_index) {
    throw_if_not_ok(labelled_array_query_->set_data_buffer(
        dimension_label->index_attribute()->name(),
        index_data_->data(),
        index_data_->data_size(),
        true));
  } else {
    labelled_array_query_->set_dimension_label_buffer(
        dimension_label->index_attribute()->name(), index_buffer);
  }

  // Set-up indexed array query (sparse array).
  throw_if_not_ok(indexed_array_query_->set_layout(Layout::UNORDERED));
  indexed_array_query_->set_dimension_label_buffer(
      dimension_label->label_attribute()->name(), label_buffer);
  if (use_local_index) {
    throw_if_not_ok(indexed_array_query_->set_data_buffer(
        dimension_label->index_dimension()->name(),
        index_data_->data(),
        index_data_->data_size(),
        true));
  } else {
    indexed_array_query_->set_dimension_label_buffer(
        dimension_label->index_dimension()->name(), index_buffer);
  }
}

void UnorderedWriteDataQuery::add_index_ranges_from_label(
    const bool, const void*, const uint64_t) {
  throw DimensionLabelDataQueryStatusException(
      "Updating index ranges is not supported on writes.");
}

bool UnorderedWriteDataQuery::completed() const {
  return indexed_array_query_->status() == QueryStatus::COMPLETED &&
         labelled_array_query_->status() == QueryStatus::COMPLETED;
}

void UnorderedWriteDataQuery::process() {
  // Write to main dimension label array.
  throw_if_not_ok(indexed_array_query_->init());
  throw_if_not_ok(indexed_array_query_->process());

  // Write to projection array.
  throw_if_not_ok(labelled_array_query_->init());
  throw_if_not_ok(labelled_array_query_->process());
}

}  // namespace tiledb::sm