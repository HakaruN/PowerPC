# Power
This is a crappy Power CPU. The goals are as follows:
A full Super scalar, pipeline, out of order processor implementing the Power ISA.

I don't think i'm very good at this, i've never taken any courses in computer architecture I just kind of figured it out myself with help from online resources. It's been working so far.

current features:
 - Direct mapped, pipelined L1-I cache with a 16K capacity (256 - 64Byte cache lines) with a 3 cycle latency.
 - Decode unit capable of detecting instruction formats. Decoding for instruction formats are implemented as follows:
    - A format,
    - B format,
    - D format
 - In order instruction queue from the front (in-order) end to the back (out-of-order) end
 - Reservation station (partialy implemented)

TODO:
 - Implement all instructions of POWER ISA 3.0B
 - Out of Order backend (multi instruction wide)
    - Reservation station
    - RAT
    - ROB
    - Functional units
    - Register file
 - Core interface units
 - Core state management
 - Process concurrency

