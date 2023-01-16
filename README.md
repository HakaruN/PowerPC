# Power
This is a crappy Power CPU. The goals are as follows:
A full Super scalar, pipeline, out of order processor implementing the Power ISA.

current features:
 - Direct mapped, pipelined L1-I cache with a 16K capacity (256 - 64Byte cache lines) with a 3 cycle latency.
 - Decode unit capable of detecting instruction formats. Decoding for instruction formats are implemented as follows:
    - A format,
    - B format,
    - D format

Others coming soon.
