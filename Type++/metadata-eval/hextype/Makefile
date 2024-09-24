CXX=/home/nbadoux/build/bin/clang++
CXXFLAGS=-std=c++14 -Wall -Wextra -Werror -Wno-unused-parameter -Wno-error -pedantic -O2 -g -fsanitize=cfi-derived-cast -fsanitize=cfi-unrelated-cast -flto -fvisibility=hidden -Wno-unused-value

all: benchmark

benchmark_gen: hextype.o hextype_report.o hextype_rbtree.o benchmark_gen.cc
	$(CXX) $(CXXFLAGS) -o benchmark_gen benchmark_gen.cc hextype.o hextype_report.o hextype_rbtree.o

benchmark: hextype.o hextype_report.o hextype_rbtree.o benchmark.cc
	$(CXX) $(CXXFLAGS) -o benchmark benchmark.cc hextype.o hextype_report.o hextype_rbtree.o
	
.PHONY: clean
clean:
	rm -f benchmark *.o 
