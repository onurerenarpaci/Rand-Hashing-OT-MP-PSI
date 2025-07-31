# Over-Threshold Multiparty Private Set Intersection for Collaborative Network Intrusion Detection

This is the experimental code for the paper "Over-Threshold Multiparty Private Set Intersection for Collaborative Network Intrusion Detection"

It includes the implementation of the protocol described in the paper, a script to run the protocol end-to-end and the benchmark scripts used to generate the graphs in the paper.

This codebase implements the non-interactive deployment option, the participants and the aggregator do not have standalone server executables, instead the message transfer between participants and the aggregator represented as temporary files saved to the "inter_data" directory. The share generation benchmarks of the Collusion Safe deployment option is done by using the Mahdavi et. al.'s [implementation](https://github.com/cryspuwaterloo/OT-MP-PSI).

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

#### Pulling the image from DockerHub

- Run the following command to pull the image from DockerHub

    ``docker pull onurerenarpaci/rand-hashing-ot-mp-psi:1.0``

- Run the following command to start the container

    ``docker run --name otmpsi -d -it onurerenarpaci/rand-hashing-ot-mp-psi:1.0``

- Run the following command to open a CLI to the container

    ``docker exec -it otmpsi bash``

#### Building the docker image from source

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

The script used for benchmarking reconstruction times is `benchmark_fig_6-9_reconstruction.jl`. It takes a JSON file as input for doing a batch of tests. The input files of the experiments in the paper is provided in the benchmark_input directory. The script outputs the results to the `benchmark_output` directory.

This script is used for generating Figures 6, 7, 8 and 9. All the inputs for each figure (except Figure 7) is inside the `benchmark_input` folder. Figure 7 was generated using the institutional network data provided by [Canarie](https://www.canarie.ca/about/) and we are not allowed to share this data. The benchmark results for the Mahdavi et. al. in Figure 6 is generated with their [implementation](https://github.com/cryspuwaterloo/OT-MP-PSI).

To quickly test the script and see and example output, you can use the `benchmark-reconstruction-test.json` file as input.

#### Options

```
-i --Input       Input filename
```

#### Example
``julia --project=. -t 16 benchmark_fig_6-9_reconstruction.jl -i benchmark-fig-6-reconstruction-cmprsn.json``

### Share Generation Benchmark

The script used for share generation times is `benchmark_fig_10-11_share_gen.jl`. It also takes a JSON file as input for doing a batch of tests. It outputs the results to the `benchmark_output` directory.

This script is used for generating Figure 10 and 11. The input for these figures is inside the `benchmark_input` folder. And as mentioned earlier, the Collusion Safe share generation results in Figure 10 and 11 are generated using Mahdavi et. al.'s [implementation](https://github.com/cryspuwaterloo/OT-MP-PSI).

To quickly test the script and see and example output, you can use the `benchmark-share-gen-test.json` file as input.

#### Options

```
-i --Input       Input filename
```

#### Example
``julia --project=. -t 16 benchmark_fig_10-11_share_gen.jl -i benchmark-fig-10-11-share-gen.json``


### Correctness Experiment

The script used for testing the correctness is `benchmark_fig_5_correctness.jl`. It outputs the results to the `benchmark_output` directory.

This script is used for generating Figure 5.

#### Options

```
-m --M          Number of elements each participant has
-t              Threshold value
-r --Trials     Number of trials
```

#### Example
``julia --project=. -t 16 benchmark_fig_5_correctness.jl -m 200 -t 3 -r 10000``







