; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-preopt=false -mem2reg -instsimplify -simplifycfg -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme,mem2reg,instsimplify,simplifycfg"  -enzyme-preopt=false -S | FileCheck %s

; Function Attrs: noinline nounwind readnone uwtable
define double @tester(double %x, double %y) {
entry:
  %0 = fmul fast double %x, %y
  ret double %0
}

define double @test_derivative(double %x, double %y) {
entry:
  %0 = tail call double (double (double, double)*, ...) @__enzyme_fwdsplit(double (double, double)* nonnull @tester, double %x, double 1.0, double %y, double 0.0, i8* null)
  ret double %0
}

; Function Attrs: nounwind
declare double @__enzyme_fwdsplit(double (double, double)*, ...)

; CHECK: define internal {{(dso_local )?}}double @fwddiffetester(double %x, double %"x'", double %y, double %"y'", i8* %tapeArg)
; CHECK-NEXT: entry:
; CHECK-NEXT:   %0 = fmul fast double %"x'", %y
; CHECK-NEXT:   %1 = fmul fast double %"y'", %x
; CHECK-NEXT:   %2 = fadd fast double %0, %1
; CHECK-NEXT:   ret double %2
; CHECK-NEXT: }
