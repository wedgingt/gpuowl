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

class Task {
 public:
 enum Kind {PRP, PM1, LL, VERIFY};
 Task(Kind k) : kind(k) { };
 Task(Kind k, const u32& e) : kind(k), exponent(e) { };
 Task(Kind k, const std::string& path) : kind(k), verifyPath(path) { };

 Task(Kind k, const u32& e, Args &args) : kind(k), exponent(e)
  { this->adjustBounds(args); };

 Task(Kind k, const u32& e, const std::string& aid, const std::string& l,
      const u32& b1, const u32& b2, const u32& low, const u32& wants)
   : kind(k), exponent(e), AID(aid), line(l), B1(b1), B2(b2), bitLo(low), wantsPm1(wants)
  { }

  Kind kind;
  u32 exponent;
  string AID;  // Assignment ID
  string line; // the verbatim worktodo line, used in deleteTask().

  u32 B1 = 0;
  u32 B2 = 0;

  u32 bitLo = 0;
  u32 wantsPm1 = 0; // An indication of how much P-1 is desired before PRP

  string verifyPath; // For Verify
  
  void adjustBounds(Args& args);
  
  void execute(const Args& args);

  void writeResultPRP(const Args&, bool isPrime, u64 res64, u32 fftSize, u32 nErrors, const fs::path& proofPath) const;
  void writeResultPM1(const Args&, const std::string& factor, u32 fftSize) const;

  string kindStr() const { return "PRP"; }
  
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
};
