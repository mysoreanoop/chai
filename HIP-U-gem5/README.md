## Instructions to compile for gem5
1. Download (or, in the Makefiles, update the path to) gem5:
`git clone https://github.com/gem5/gem5`
2. Employ the published docker image to compile libm5.a:
`docker run -u $UID:$GID --volume $(pwd):$(pwd) -w $(pwd) gcr.io/gem5-test/gcn-gpu:v22-1 scons -C gem5/util/m5  x86.CROSS_COMPILE=x86_64-linux-gnu- build/x86/out/libm5.a`
PS: if the gem5 directory is not a strict-subdirectory of $(pwd), docker might not find it; the solution is to launch docker from at least the same directory as gem5, or upwards.
3. Compile the benchmark of choice (for example, BFS):
`docker run -u $UID:$GID --volume $(pwd):$(pwd) -w $(pwd) gcr.io/gem5-test/gcn-gpu:v22-1 make -B -C <program> GEM5_PATH=<path to gem5>`
PS: the compiled binary will be in `<program>/bin/<program>`

## Instructions to run on gem5
PS: The tests are run against gem5's GCN3 model using apu\_se.py config.
Run from the directory containing gem5 and gem5-resources:
`docker run -u $UID:$GID --volume $(pwd):$(pwd) -w $(pwd) gcr.io/gem5-test/gcn-gpu:v22-1 gem5/build/GCN3_X86/gem5.opt -d chai_cedd/ gem5/configs/example/apu_se.py --cpu-type=DerivO3CPU --num-cpus=8 --mem-size=4GB -c gem5-resources/src/gpu/chai/HIP-U-gem5/CEDD/bin/cedd.gem5 --options="-f gem5-resources/src/gpu/chai/HIP-U-gem5/BS/input/peppa/ <any other arguments as required by the program>" 1>chai_cedd_simout 2>chai_cedd_simerr`

## Errata
Data Paritioning:
```
Both  BS     Works
Main  CEDD   Works                (with develop) Doesn't terminate
Main  HSTI   Works                (with develop) gem5.opt: src/mem/ruby/system/GPUCoalescer.cc:635: void gem5::ruby::GPUCoalescer::hitCallback(gem5::ruby::CoalescedRequest*, gem5::ruby::MachineType, gem5::ruby::DataBlock&, bool, gem5::Cycles, gem5::Cycles, gem5::Cycles, bool): Assertion `data.numAtomicLogEntries() == 0' failed.
Dev   HSTO   Works                (with main)    Doesn't terminate
Main  PAD    Works                (with develop) gem5.opt: src/mem/ruby/system/GPUCoalescer.cc:635: void gem5::ruby::GPUCoalescer::hitCallback(gem5::ruby::CoalescedRequest*, gem5::ruby::MachineType, gem5::ruby::DataBlock&, bool, gem5::Cycles, gem5::Cycles, gem5::Cycles, bool): Assertion `data.numAtomicLogEntries() == 0' failed.
      SC                          src/mem/xbar.cc:368: fatal: Unable to find destination for [0x20001000:0x20001001] on system.piobus
                                  Use --debug-flags=PortTrace to see the port trace of the packet.
                                  (but, with the flag...)
                                  src/mem/port.cc:209: panic: panic condition !ext occurred: There is no TracingExtension in the packet.
      RSCD                        (same as SC)
      TRNS                        (same as SC)
```

Fine-grained Task Partitioning:
```
Both  RSCT   Verification failed 
                                  The best fitting model computed by the verification code does not match the model identified by GPU+CPU
                                    will need to contact CHAI folks for algorithm insight (or read the reference paper)
Both  TQ     Works 
      TQH    Running in new
                                  (same as SC)
```

Coarse-grained Task Partitioning:
```
      BFS                         gem5.opt: src/mem/ruby/system/GPUCoalescer.cc:607: void gem5::ruby::GPUCoalescer::hitCallback(gem5::ruby::CoalescedRequest*, gem5::ruby::MachineType, gem5::ruby::DataBlock&, bool, gem5::Cycles, gem5::Cycles, gem5::Cycles, bool): Assertion `data.numAtomicLogEntries() == 0' failed.
                                    number of atomic response packets at the coalescer is not consistent with the requests coalesced, so there are some slots of the colescer waiting for responses that never arrive
                                    might relate to a recent git commit trying to handle it -- perhaps a useful test case.
      CEDT                        Stuck (GPU not launched)
      SSSP   Fails, but completes with less data 
                                  Tried to read unmapped address -- too slow to read data in
```
