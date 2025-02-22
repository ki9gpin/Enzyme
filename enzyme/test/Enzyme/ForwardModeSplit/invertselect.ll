; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -mem2reg -early-cse -simplifycfg -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme,mem2reg,early-cse,simplifycfg"  -enzyme-preopt=false -S | FileCheck %s

; Function Attrs: noinline nounwind uwtable
define dso_local float @man_max(float* %a, float* %b) #0 {
entry:
  %0 = load float, float* %a, align 4
  %1 = load float, float* %b, align 4
  %cmp = fcmp ogt float %0, %1
  %a.b = select i1 %cmp, float* %a, float* %b
  %retval.0 = load float, float* %a.b, align 4
  ret float %retval.0
}

define void @dman_max(float* %a, float* %da, float* %b, float* %db) {
entry:
  call float (...) @__enzyme_fwdsplit.f64(float (float*, float*)* @man_max, float* %a, float* %da, float* %b, float* %db, i8* null)
  ret void
}

declare float @__enzyme_fwdsplit.f64(...)

attributes #0 = { noinline }


; CHECK: define internal float @fwddiffeman_max(float* %a, float* %"a'", float* %b, float* %"b'", i8* %tapeArg)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = bitcast i8* %tapeArg to i1*
; CHECK-NEXT:   %cmp = load i1, i1* %0
; CHECK-NEXT:   tail call void @free(i8* nonnull %tapeArg)
; CHECK-NEXT:   %"a.b'ipse" = select i1 %cmp, float* %"a'", float* %"b'"
; CHECK-NEXT:   %[[i1:.+]] = load float, float* %"a.b'ipse"
; CHECK-NEXT:   ret float %[[i1]]
; CHECK-NEXT: }
