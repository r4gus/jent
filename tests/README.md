# Jitter RNG entropy analysis

See also: [Jitter RNG SP800-90B Entropy Analysis Tool -- smuellerDD](https://github.com/smuellerDD/jitterentropy-library/tree/master/tests/raw-entropy)

Analysis tool for the Jitter RNG.

Please note that this was just recently ported from the original repository and might have inaccuracies
that distort the results.

* `recording_userspace` - Tool for gathering raw entropy using the Jitter RNG. After executing `zig build` you can find the executable `hashtime` in `zig-out/bin`.
    * Usage Example: `./zig-out/bin/hashtime 1000000 1 $(pwd)/tests/results-measurements/jent-raw-noise`

## Usage

1. Download the [SP800-90B\_EntropyAssessment](https://github.com/usnistgov/SP800-90B_EntropyAssessment) repository and then build it.

2. Run the `hashtime` user space entropy collector
    * `./zig-out/bin/hashtime 1000000 1 $(pwd)/tests/results-measurements/jent-raw-noise`

3. Run `processdata.sh`

You can find the results in `results-analysis-runtime`.

## Interpretation of Results

The result of the data analysis performed \[..\] contains in the file `jent-raw-noise-1.minentropy_FF_8bits.var.txt` at the bottom data like the following:

```
H_original: 7.353758
H_bitstring: 0.935706
min(H_original, 8 X H_bitstring): 7.353758
```

The last value gives you the entropy estimate per time delta. That means for one time delta the given number of entropy in bits is collected on average.

Per default, the Jitter RNG heuristic applies 1/3 bit of entropy per time delta. This implies that the measurement must show that at least 1/3 bit of entropy is present. In the example above, the measurement shows that 7.3 bits of entropy is present which implies that the available amount of entropy is more than what the Jitter RNG heuristic applies.
