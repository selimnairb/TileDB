# Fragment

## Main Structure

A fragment metadata folder is called `<timestamped_name>` and located here:

```
my_array                              # array folder
   |  ...
   |_ <timestamped_name>              # fragment folder
   |      |_ __fragment_metadata.tdb  # fragment metadata
   |      |_ a1.tdb                   # fixed-sized attribute 
   |      |_ a2.tdb                   # var-sized attribute (offsets) 
   |      |_ a2_var.tdb               # var-sized attribute (values)
   |      |_ ...      
   |      |_ d1.tdb                   # fixed-sized dimension 
   |      |_ d2.tdb                   # var-sized dimension (offsets) 
   |      |_ d2_var.tdb               # var-sized dimension (values)
   |      |_ ...      
   |_ ...  
```

`<timestamped_name>` has format `__t1_t2_uuid_v`, where:
* `t1` and `t2` are timestamps in milliseconds elapsed since 1970-01-01 00:00:00 +0000 (UTC)
* `uuid` is a unique identifier
* `v` is the format version

There can be any number of fragments in an array. The fragment folder contains:
* A single [fragment metadata file](#fragment-metadata-file) named `__fragment_metadata.tdb`. 
* Any number of [data files](#data-file). For each fixed-sized attribute `a1` (or dimension `d1`), there is a single data file `a1.tdb` (`d1.tdb`) containing the values along this attribute (dimension). For every var-sized attribute `a2` (or dimensions `d2`), there are two data files; `a2_var.tdb` (`d2_var.tdb`) containing the var-sized values of the attribute (dimension) and `a2.tdb` (`d2.tdb`) containing the starting offsets of each value in `a2_var.tdb` (`d2_var.rdb`).

## Fragment Metadata File 

The fragment metadata file has the following on-disk format:

| **Field** | **Type** | **Description** |
| :--- | :--- | :--- |
| R-Tree | [R-Tree](#r-tree) | The serialized R-Tree |
| Tile offsets for attribute/dimension 1 | [Tile Offsets](#tile-offsets) | The serialized tile offsets for attribute/dimension 1 |
| … | … | … |
| Tile offsets for attribute/dimension N | [Tile Offsets](#tile-offsets) | The serialized tile offsets for attribute/dimension N |
| Variable tile offsets for attribute/dimension 1 | [Tile Offsets](#tile-offsets) | The serialized variable tile offsets for attribute/dimension 1 |
| … | … | … |
| Variable tile offsets for attribute/dimension N | [Tile Offsets](#tile-offsets) | The serialized variable tile offsets for attribute/dimension N |
| Variable tile sizes for attribute/dimension 1 | [Tile Offsets](#tile-offsets) | The serialized variable tile sizes for attribute/dimension 1 |
| … | … | … |
| Variable tile sizes for attribute/dimension N | [Tile Offsets](#tile-offsets) | The serialized variable tile sizes for attribute/dimension N |
| Metadata footer | [Footer](#footer) | Basic metadata gathered in the footer |

### R-Tree

The R-Tree is a [generic tile](./generic_tile.md) with the following internal format:

| **Field** | **Type** | **Description** |
| :--- | :--- | :--- |
| Fanout | `uint32_t` | The tree fanout |
| Num levels | `uint32_t` | The number of levels in the tree |
| Num MBRs at level 1 | `uint64_t` | The number of MBRs at level 1 |
| MBR 1 at level 1 | [MBR](#mbr) | First MBR at level 1 |
| … | … | … |
| MBR N at level 1 | [MBR](#mbr) | N-th MBR at level 1 |
| … | … | … |
| Num MBRs at level L | `uint64_t` | The number of MBRs at level L |
| MBR 1 at level L | [MBR](#mbr) | First MBR at level L |
| … | … | … |
| MBR N at level L | [MBR](#mbr) | N-th MBR at level L |

### MBR

Each MBR entry has format:

| **Field** | **Type** | **Description** |
| :--- | :--- | :--- |
| 1D range for dimension 1 | `1DRange` | The 1-dimensional range for dimension 1 |
| … | … | … |
| 1D range for dimension D | `1DRange` | The 1-dimensional range for dimension D |

For *fixed-sized dimensions*, the `1DRange` format is:

| **Field** | **Type** | **Description** |
| :--- | :--- | :--- |
| Range minimum | `uint8_t` | The minimum value with the same datatype as the dimension |
| Range maximum | `uint8_t` | The maximum value with the same datatype as the dimension |

For *var-sized dimensions*, the `1DRange` format is:

| **Field** | **Type** | **Description** |
| :--- | :--- | :--- |
| Range length | `uint64_t` | The number of bytes of the 1D range |
| Minimum value length | `uint64_t` | The number of bytes of the minimum value |
| Range minimum | `uint8_t` | The minimum (var-sized) value with the same datatype as the dimension |
| Range maximum | `uint8_t` | The maximum (var-sized) value with the same datatype as the dimension |

### Tile Offsets

The tile offsets is a [generic tile](./generic_tile.md) with the following internal format:

| **Field** | **Type** | **Description** |
| :--- | :--- | :--- |
| Num tile offsets | `uint64_t` | Number of tile offsets |
| Tile offset 1 | `uint64_t` | Offset 1 |
| … | … | … |
| Tile offset N | `uint64_t` | Offset N |

### Tile Sizes

The tile sizes is a [generic tile](./generic_tile.md) with the following internal format:

| **Field** | **Type** | **Description** |
| :--- | :--- | :--- |
| Num tile sizes | `uint64_t` | Number of tile sizes |
| Tile size 1 | `uint64_t` | Size 1 |
| … | … | … |
| Tile size N | `uint64_t` | Size N |

### Footer

The footer is a simple blob \(i.e., _not a generic tile_\) with the following internal format:

| **Field** | **Type** | **Description** |
| :--- | :--- | :--- |
| Version number | `uint32_t` | Format version number of the fragment |
| Dense | `char` | Whether the array is dense |
| Null non-empty domain | `char` | Indicates whether the non-empty domain is null or not |
| Non-empty domain | [MBR](#mbr) | An MBR denoting the non-empty domain |
| Number of sparse tiles | `uint64_t` | Number of sparse tiles |
| Last tile cell num | `uint64_t` | For sparse arrays, the number of cells in the last tile in the fragment |
| File sizes | `uint64_t[]` | The size in bytes of each attribute/dimension file in the fragment. For var-length attributes/dimensions, this is the size of the offsets file. |
| File var sizes | `uint64_t[]` | The size in bytes of each var-length attribute/dimension file in the fragment. |
| R-Tree offset | `uint64_t` | The offset to the generic tile storing the R-Tree in the metadata file. |
| Tile offset for attribute/dimension 1 | `uint64_t` | The offset to the generic tile storing the tile offsets for attribute/dimension 1. |
| … | … | … |
| Tile offset for attribute/dimension N | `uint64_t` | The offset to the generic tile storing the tile offsets for attribute/dimension N |
| Tile var offset for attribute/dimension 1 | `uint64_t` | The offset to the generic tile storing the variable tile offsets for attribute/dimension 1. |
| … | … | … |
| Tile var offset for attribute/dimension N | `uint64_t` | The offset to the generic tile storing the variable tile offsets for attribute/dimension N. |
| Tile var sizes offset for attribute/dimension 1 | `uint64_t` | The offset to the generic tile storing the variable tile sizes for attribute/dimension 1. |
| … | … | … |
| Tile var sizes offset for attribute/dimension N | `uint64_t` | The offset to the generic tile storing the variable tile sizes for attribute/dimension N. |
| Footer length | `uint64_t` | Sum of bytes of the above fields. Only present when there is at least one var-sized dimension. |

## Data File 

The on-disk format of each data file is:

| **Field** | **Type** | **Description** |
| :--- | :--- | :--- |
| Tile 1 | [Tile](./tile.md#tile) | The data of tile 1 |
| … | … | … |
| Tile N | [Tile](./tile.md#tile) | The data of tile N |
