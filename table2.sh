#!/bin/bash
cd ${HOME}/LLVM-typepp
docker build . --target cpu_reference -t cpu_reference
docker build . --target cpu_cfi -t cpu_cfi
docker build . --target cpu_typepp -t cpu_typepp

# these builds allow the collection of cast statistics
docker build . --target cpu_cfi_stats -t cpu_cfi_stats
docker build . --target cpu_typepp_stats -t cpu_typepp_stats

# these builds allow the collection of memory measurements
docker build . --target memory_reference -t memory_reference
docker build . --target memory_typepp -t memory_typepp

cd ${HOME}/LLVM-typepp
mkdir -p results
# run the experiment
docker run --env NUMBER_OF_ITERATION=$NUMBER_OF_REPLICATION --name cpu_reference_container -t cpu_reference
# collect the results
docker container cp  cpu_reference_container:/home/nbadoux/results results_baseline
cat results_baseline/runtime_performance.csv >> ./results/runtime_performance.csv

# run the experiment
docker run --env NUMBER_OF_ITERATION=$NUMBER_OF_REPLICATION --name cpu_cfi_container -t cpu_cfi 
# collect the results
docker container cp  cpu_cfi_container:/home/nbadoux/results results_cfi
cat results_cfi/runtime_performance.csv >> ./results/runtime_performance.csv

# run the experiment
docker run --env NUMBER_OF_ITERATION=$NUMBER_OF_REPLICATION --name cpu_typepp_container -t cpu_typepp 
# collect the results
docker container cp  cpu_typepp_container:/home/nbadoux/results results_typepp
cat results_typepp/runtime_performance.csv >> ./results/runtime_performance.csv

cd ${HOME}/LLVM-typepp
# run the experiment
docker run --env NUMBER_OF_ITERATION=1 --name cpu_cfi_stats_container -t cpu_cfi_stats 
# collect the results
docker container cp  cpu_cfi_stats_container:/home/nbadoux/results results_cfi_stats
cp results_cfi_stats/total_result* results

# run the experiment
docker run --env NUMBER_OF_ITERATION=1 --name cpu_typepp_stats_container -t cpu_typepp_stats 
# collect the results
docker container cp  cpu_typepp_stats_container:/home/nbadoux/results results_typepp_stats
cp results_typepp_stats/total_result* results

cd ${HOME}/LLVM-typepp
# run the experiment
docker run --env NUMBER_OF_ITERATION=${NUMBER_OF_REPLICATION} --name memory_reference_container -t memory_reference
# collect the results
docker container cp  memory_reference_container:/home/nbadoux/results results_baseline_memory
cp results_baseline_memory/total_result_memory_baseline_* ./results/

# run the experiment
docker run --env NUMBER_OF_ITERATION=${NUMBER_OF_REPLICATION} --name memory_typepp_container -t memory_typepp 
# collect the results
docker container cp  memory_typepp_container:/home/nbadoux/results results_typepp_memory
cp results_typepp_memory/total_result_memory_vtype_* ./results/

export RESULT_FOLDER=./results
./Type++/script/getmemoryoverhead.py &&  ./Type++/script/getperformanceresult.py
