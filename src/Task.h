// gpuOwL, a GPU OpenCL Lucas-Lehmer primality checker.
// Copyright (C) 2017-2018 Mihai Preda.

#pragma once

#include "Args.h"
#include "common.h"
#include <string>
#include <cstdio>
#include <atomic>

class Args;
class Result;
class Background;

struct Task {
  enum Kind {PRP, VERIFY, PM1, LL};

  Kind kind;
  u32 exponent;
  string AID;  // Assignment ID
  string line; // the verbatim worktodo line, used in deleteTask().

  u32 B1 = 0;
  u32 B2 = 0;
  u32 howFarFactored = 0;

  string verifyPath; // For Verify
    
  void execute(const Args& args);

  void writeResultPRP(const Args&, bool isPrime, u64 res64, u32 fftSize, u32 nErrors, const fs::path& proofPath) const;
  void writeResultPM1(const Args&, const std::string& factor, u32 fftSize) const;

  // string kindStr() const;
  
  /*
  operator string() const {
    string prefix;
    char buf[256];
    if (B1 || B2) {
      snprintf(buf, sizeof(buf), "B1=%u,B2=%u;", B1, B2);
      prefix = buf;
    }
    snprintf(buf, sizeof(buf), "%s=%s,1,2,%u,-1,%u,%u", kindStr().c_str(), AID.empty() ? "N/A" : AID.c_str(), exponent, bitLo, wantsPm1);
    return buf;
  }
  */
};
