# Non-Interactive Over-Threshold Multiparty Private Set Intersection

This is the experimental code for the paper "Non-Interactive Over-Threshold Multiparty Private Set Intersection"

It includes the implementation of the protocol described in the paper, a script to run the protocol end-to-end and the benchmark scripts used to generate the graphs in the paper.

Since the protocol is non-interactive, we do not test for network delays, so the participants and the aggregator do not have standalone server executables, instead the message transfer between participants and the aggregator represented as temporary files saved to the "inter_data" directory.

## Installation
We provide instructions for using the project locally and with docker.

### Local Installation
- Install the julia version manager juliaup by following the instructions in https://github.com/JuliaLang/juliaup

- Install julia 1.10 by running the command 
    
    ``juliaup add 1.10``

- Make julia 1.10 the default version by running 

    ``juliaup default 1.10``

- Clone the repository and `cd` into it

- Run the following command to install the dependencies

    ``julia --project=. -e 'using Pkg; Pkg.instantiate()'``

### Docker Installation
- If you don't have a docker installation follow the instructions in https://docs.docker.com/engine/install/

- Clone the repository and `cd` into it

- Run the following command to build the image
    
    ``docker build --tag ot-mp-psi:1.0 .``

- Run the following command to start the container

    ``docker run --name otmpsi -d -it ot-mp-psi:1.0``

- Run the following command to open a CLI to the container

    ``docker exec -it otmpsi bash``

## Usage

All the scripts can be executed with the following command template

``julia --project=. -t <number of threads> <script file name> <script options>``

### End-to-end Test

You can test the full protocol by running the the `end-to-end.jl` file

#### Options

```
-m --M          Number of elements each participant has
-n --N          Number of participants
-t              The threshold value
```

#### Example
``julia --project=. -t 16 end-to-end.jl -m 1000 -n 10 -t 4``

### Reconstruction Benchmark

The script used for benchmarking reconstruction times is `benchmark_reconstruction.jl`. It takes a JSON file as input for doing a batch of tests. The input files of the experiments in the paper is provided in the benchmark_input directory. The script outputs the results to the `benchmark_output` directory.

#### Options

```
-i --Input       Input filename
```

#### Example
``julia --project=. -t 16 benchmark_reconstruction.jl -i benchmark-reconstruction-N.json``

### Share Generation Benchmark

The script used for share generation reconstruction times is `benchmark_share_gen.jl`. It also takes a JSON file as input for doing a batch of tests. It outputs the results to the `benchmark_output` directory.

#### Options

```
-i --Input       Input filename
```

#### Example
``julia --project=. -t 16 benchmark_share_gen.jl -i benchmark-share-gen.json``


### Correctness Experiment

The script used for testing the correctness is `benchmark_correctness.jl`. It outputs the results to the `benchmark_output` directory.

#### Options

```
-m --M          Number of elements each participant has
-t              Threshold value
-r --Trials     Number of trials
```

#### Example
``julia --project=. -t 16 benchmark_correctness.jl -m 200 -t 3 -r 10000``







