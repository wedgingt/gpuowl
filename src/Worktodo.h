// gpuOwL, a GPU OpenCL Lucas-Lehmer primality checker.
// Copyright (C) Mihai Preda.

#pragma once

#include "Args.h"
#include "Task.h"
#include "common.h"
#include <optional>

class Worktodo {
public:
  static std::optional<Task> getTask(Args &args);
  static bool deleteTask(const Task &task);
  
  static Task makePRP(Args &args, u32 exponent) {
   Task task;
   task.kind = Task::PRP;
   task.exponent = exponent;
   return task;
  }

  static Task makePM1(Args &args, u32 exponent) {
   Task task;
   task.kind = Task::PM1;
   task.exponent = exponent;
   //!! task.? = args;
   return task;
  }

  static Task makeLL(Args& args, u32 exponent) {
   Task task;
   task.kind = Task::LL;
   task.exponent = exponent;
   return task;
  }

  static Task makeVerify(Args& args, string path) {
   Task task;
   task.kind = Task::VERIFY;
   task.verifyPath = path;
   return task;
  }
};
