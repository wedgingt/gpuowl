// Copyright Mihai Preda.

#pragma once

#include "Buffer.h"
#include "Context.h"
#include "Queue.h"

#include "common.h"
#include "kernel.h"

#include <vector>
#include <string>
#include <memory>
#include <variant>
#include <atomic>

struct Args;
struct PRPResult;
struct PRPState;

using double2 = pair<double, double>;

class Gpu {
  friend class SquaringSet;
  u32 E;
  u32 N;

  u32 hN, nW, nH, bufSize;
  u32 WIDTH;
  bool useLongCarry;
  bool useMergedMiddle;
  bool timeKernels;

  cl_device_id device;
  Context context;
  Holder<cl_program> program;
  QueuePtr queue;
  
  Kernel carryFused;
  Kernel carryFusedMul;
  Kernel carryFusedLL;
  Kernel fftP;
  Kernel fftW;
  Kernel fftHin;
  Kernel fftHout;
  Kernel fftMiddleIn;
  Kernel fftMiddleOut;
  
  Kernel carryA;
  Kernel carryM;
  Kernel carryB;
  Kernel carryLL;
  
  Kernel transposeW, transposeH;
  Kernel transposeIn, transposeOut;

  Kernel multiply;
  Kernel multiplyDelta;
  Kernel square;
  Kernel tailFusedSquare;
  Kernel tailFusedMulDelta;
  Kernel tailFusedMulLow;
  Kernel tailFusedMul;
  Kernel tailSquareLow;
  Kernel tailMulLowLow;
  
  Kernel readResidue;
  Kernel isNotZero;
  Kernel isEqual;
  Kernel sum64;

  // Trigonometry constant buffers, used in FFTs.
  ConstBuffer<double2> bufTrigW;
  ConstBuffer<double2> bufTrigH;
  ConstBuffer<double2> bufTrigM;

  // Weight constant buffers, with the direct and inverse weights. N x double.
  ConstBuffer<double> bufWeightA;      // Direct weights.
  ConstBuffer<double> bufWeightI;      // Inverse weights.

  ConstBuffer<u32> bufBits;
  ConstBuffer<u32> bufExtras;
  ConstBuffer<double> bufGroupWeights;
  ConstBuffer<double> bufThreadWeights;
  
  // "integer word" buffers. These are "small buffers": N x int.
  HostAccessBuffer<int> bufData;   // Main int buffer with the words.
  HostAccessBuffer<int> bufAux;    // Auxiliary int buffer, used in transposing data in/out and in check.
  Buffer<int> bufCheck;  // Buffers used with the error check.
  
  // Carry buffers, used in carry and fusedCarry.
  Buffer<i64> bufCarry;  // Carry shuttle.
  
  Buffer<int> bufReady;  // Per-group ready flag for stairway carry propagation.
  HostAccessBuffer<u32> bufRoundoff;
  HostAccessBuffer<u32> bufCarryMax;
  HostAccessBuffer<u32> bufCarryMulMax;

  // Small aux buffer used to read res64.
  HostAccessBuffer<int> bufSmallOut;
  HostAccessBuffer<u64> bufSumOut;

  // Auxilliary big buffers
  Buffer<double> buf1;
  Buffer<double> buf2;
  Buffer<double> buf3;
  
  const Args& args;
  
  vector<u32> computeBase(u32 E, u32 B1);
  pair<vector<u32>, vector<u32>> seedPRP(u32 E, u32 B1);
  
  vector<int> readSmall(Buffer<int>& buf, u32 start);

  void tW(Buffer<double>& out, Buffer<double>& in);
  void tH(Buffer<double>& out, Buffer<double>& in);
  void tailFused(Buffer<double>& out, Buffer<double>& in) { tailFusedSquare(out, in); }
  
  vector<int> readOut(ConstBuffer<int> &buf);
  void writeIn(Buffer<int>& buf, const vector<i32> &words);

  void modSqLoopRaw(Buffer<int>& io, u32 reps, Buffer<double>& buf1, Buffer<double>& buf2, bool mul3, bool sub2);
  
  void modSqLoop(Buffer<int>& io, u32 reps, Buffer<double>& buf1, Buffer<double>& buf2) {
    modSqLoopRaw(io, reps, buf1, buf2, false, false);
  }
  void modSqLoopMul(Buffer<int>& io, u32 reps, Buffer<double>& buf1, Buffer<double>& buf2) {
    modSqLoopRaw(io, reps, buf1, buf2, true, false);
  }
  void modSqLoopLL(Buffer<int>& io, u32 reps, Buffer<double>& buf1, Buffer<double>& buf2) {
    modSqLoopRaw(io, reps, buf1, buf2, false, true);
  }
  
  u32 modSqLoopTo(Buffer<int>& io, u32 begin, u32 end);

  void modMul(Buffer<int>& io, Buffer<int>& in, Buffer<double>& buf1, Buffer<double>& buf2, Buffer<double>& buf3, bool mul3 = false);
  bool equalNotZero(Buffer<int>& bufCheck, Buffer<int>& bufAux);
  u64 bufResidue(Buffer<int>& buf);
  
  vector<u32> writeBase(const vector<u32> &v);

  PRPState loadPRP(u32 E, u32 iniBlockSize, Buffer<double>&, Buffer<double>&, Buffer<double>&);

  void coreStep(bool leadIn, bool leadOut, bool mul3, bool sub2, Buffer<double>& buf1, Buffer<double>& buf2, Buffer<int>& io);

  void multiplyLow(Buffer<double>& io, const Buffer<double>& in, Buffer<double>& tmp);

  void exponentiateCore(Buffer<double>& out, const Buffer<double>& base, u64 exp, Buffer<double>& tmp);
  void exponentiateLow(Buffer<double>& out, const Buffer<double>& base, u64 exp, Buffer<double>& tmp, Buffer<double>& tmp2);
  void exponentiateHigh(Buffer<int>& bufInOut, u64 exp, Buffer<double>& bufBaseLow, Buffer<double>& buf1, Buffer<double>& buf2);
  
  void topHalf(Buffer<double>& out, Buffer<double>& inTmp);
  void writeState(const vector<u32> &check, u32 blockSize, Buffer<double>&, Buffer<double>&, Buffer<double>&);
  void tailMulDelta(Buffer<double>& out, Buffer<double>& in, Buffer<double>& bufA, Buffer<double>& bufB);
  void tailMul(Buffer<double>& out, Buffer<double>& in, Buffer<double>& inTmp);
  

  Gpu(const Args& args, u32 E, u32 W, u32 BIG_H, u32 SMALL_H, u32 nW, u32 nH,
      cl_device_id device, bool timeKernels, bool useLongCarry, struct Weights&& weights, bool isPm1);

  void printRoundoff(u32 E);

  // does either carrryFused() or the expanded version depending on useLongCarry
  void doCarry(Buffer<double>& out, Buffer<double>& in);
  
public:
  static unique_ptr<Gpu> make(u32 E, const Args &args, bool isPm1);
  static void doDiv9(u32 E, Words& words);
  static bool equals9(const Words& words);
  static u64 residue(const Words& words) { return (u64(words[1]) << 32) | words[0]; }
  
  Gpu(const Args& args, u32 E, u32 W, u32 BIG_H, u32 SMALL_H, u32 nW, u32 nH,
      cl_device_id device, bool timeKernels, bool useLongCarry, bool isPm1);

  vector<u32> readAndCompress(ConstBuffer<int>& buf);
  void writeIn(Buffer<int>& buf, const vector<u32> &words);
  void writeData(const vector<u32> &v) { writeIn(bufData, v); }
  void writeCheck(const vector<u32> &v) { writeIn(bufCheck, v); }
  
  u64 dataResidue()  { return bufResidue(bufData); }
  u64 checkResidue() { return bufResidue(bufCheck); }
    
  bool doCheck(u32 blockSize, Buffer<double>&, Buffer<double>&, Buffer<double>&);
  void updateCheck(Buffer<double>& buf1, Buffer<double>& buf2, Buffer<double>& buf3);

  void finish();

  void logTimeKernels();

  vector<u32> readCheck() { return readAndCompress(bufCheck); }
  vector<u32> readData() { return readAndCompress(bufData); }

  std::tuple<bool, u64, u32> isPrimePRP(u32 E, const Args& args, std::atomic<u32>& factorFoundForExp);
  std::tuple<bool, u64> isPrimeLL(u32 E, const Args& args);

  std::variant<string, vector<u32>> factorPM1(u32 E, const Args& args, u32 B1, u32 B2);
  
  u32 getFFTSize() { return N; }

  // return A^h * B
  Words expMul(const Words& A, u64 h, const Words& B);

  // A:= A^h * B
  void expMul(Buffer<i32>& A, u64 h, Buffer<i32>& B);
  
  // return A^(2^n)
  Words expExp2(const Words& A, u32 n);
  vector<Buffer<i32>> makeBufVector(u32 size);
};
