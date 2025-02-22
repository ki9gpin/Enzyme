; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --include-generated-funcs
; RUN: %opt < %s %loadEnzyme -enzyme -enzyme-lower-globals -mem2reg -sroa -simplifycfg -instsimplify -S | FileCheck %s
; RUN: %opt < %s %newLoadEnzyme -passes="enzyme,mem2reg,sroa,instsimplify,simplifycfg" -enzyme-lower-globals -enzyme-preopt=false -S | FileCheck %s

%struct.Gradients = type { double, double, double }

; Function Attrs: nounwind
declare %struct.Gradients @__enzyme_fwddiff(double (double)*, ...)

@global = external dso_local local_unnamed_addr global double, align 8

; Function Attrs: noinline norecurse nounwind readonly uwtable
define double @mulglobal(double %x) {
entry:
  %l1 = load double, double* @global, align 8
  %mul = fmul fast double %l1, %x
  store double %mul, double* @global, align 8
  %l2 = load double, double* @global, align 8
  %mul2 = fmul fast double %l2, %l2
  store double %mul2, double* @global, align 8
  %l3 = load double, double* @global, align 8
  ret double %l3
}

; Function Attrs: noinline nounwind uwtable
define %struct.Gradients @derivative(double %x) {
entry:
  %0 = tail call %struct.Gradients (double (double)*, ...) @__enzyme_fwddiff(double (double)* nonnull @mulglobal, metadata !"enzyme_width", i64 3, double %x, double 1.0, double 2.0, double 3.0)
  ret %struct.Gradients %0
}

; CHECK: define {{[^@]+}}@fwddiffe3mulglobal(double [[X:%.*]], [3 x double] %"x'")
; CHECK-NEXT:  entry:
; CHECK-NEXT:    %"global'ipa" = alloca double, align 8
; CHECK-NEXT:    %"global'ipa1" = alloca double, align 8
; CHECK-NEXT:    %"global'ipa2" = alloca double, align 8
; CHECK-NEXT:    [[TMP0:%.*]] = bitcast double* %"global'ipa" to i8*
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* nonnull align 8 [[TMP0]], i8 0, i64 8, i1 false)
; CHECK-NEXT:    [[TMP1:%.*]] = bitcast double* %"global'ipa1" to i8*
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* nonnull align 8 [[TMP1]], i8 0, i64 8, i1 false)
; CHECK-NEXT:    [[TMP2:%.*]] = bitcast double* %"global'ipa2" to i8*
; CHECK-NEXT:    call void @llvm.memset.p0i8.i64(i8* nonnull align 8 [[TMP2]], i8 0, i64 8, i1 false)
; CHECK-NEXT:    %"global_local.0.copyload'ipl" = load double, double* %"global'ipa", align 8
; CHECK-NEXT:    %"global_local.0.copyload'ipl3" = load double, double* %"global'ipa1", align 8
; CHECK-NEXT:    %"global_local.0.copyload'ipl4" = load double, double* %"global'ipa2", align 8
; CHECK-NEXT:    [[GLOBAL_LOCAL_0_COPYLOAD:%.*]] = load double, double* @global, align 8
; CHECK-NEXT:    [[MUL:%.*]] = fmul fast double [[GLOBAL_LOCAL_0_COPYLOAD]], [[X]]
; CHECK-NEXT:    [[TMP3:%.*]] = extractvalue [3 x double] %"x'", 0
; CHECK-NEXT:    [[TMP4:%.*]] = fmul fast double %"global_local.0.copyload'ipl", [[X]]
; CHECK-NEXT:    [[TMP5:%.*]] = fmul fast double [[TMP3]], [[GLOBAL_LOCAL_0_COPYLOAD]]
; CHECK-NEXT:    [[TMP6:%.*]] = fadd fast double [[TMP4]], [[TMP5]]
; CHECK-NEXT:    [[TMP7:%.*]] = extractvalue [3 x double] %"x'", 1
; CHECK-NEXT:    [[TMP8:%.*]] = fmul fast double %"global_local.0.copyload'ipl3", [[X]]
; CHECK-NEXT:    [[TMP9:%.*]] = fmul fast double [[TMP7]], [[GLOBAL_LOCAL_0_COPYLOAD]]
; CHECK-NEXT:    [[TMP10:%.*]] = fadd fast double [[TMP8]], [[TMP9]]
; CHECK-NEXT:    [[TMP11:%.*]] = extractvalue [3 x double] %"x'", 2
; CHECK-NEXT:    [[TMP12:%.*]] = fmul fast double %"global_local.0.copyload'ipl4", [[X]]
; CHECK-NEXT:    [[TMP13:%.*]] = fmul fast double [[TMP11]], [[GLOBAL_LOCAL_0_COPYLOAD]]
; CHECK-NEXT:    [[TMP14:%.*]] = fadd fast double [[TMP12]], [[TMP13]]
; CHECK-NEXT:    [[MUL2:%.*]] = fmul fast double [[MUL]], [[MUL]]
; CHECK-NEXT:    [[TMP15:%.*]] = fmul fast double [[TMP6]], [[MUL]]
; CHECK-NEXT:    [[TMP16:%.*]] = fmul fast double [[TMP6]], [[MUL]]
; CHECK-NEXT:    [[TMP17:%.*]] = fadd fast double [[TMP15]], [[TMP16]]
; CHECK-NEXT:    [[TMP18:%.*]] = insertvalue [3 x double] undef, double [[TMP17]], 0
; CHECK-NEXT:    [[TMP19:%.*]] = fmul fast double [[TMP10]], [[MUL]]
; CHECK-NEXT:    [[TMP20:%.*]] = fmul fast double [[TMP10]], [[MUL]]
; CHECK-NEXT:    [[TMP21:%.*]] = fadd fast double [[TMP19]], [[TMP20]]
; CHECK-NEXT:    [[TMP22:%.*]] = insertvalue [3 x double] [[TMP18]], double [[TMP21]], 1
; CHECK-NEXT:    [[TMP23:%.*]] = fmul fast double [[TMP14]], [[MUL]]
; CHECK-NEXT:    [[TMP24:%.*]] = fmul fast double [[TMP14]], [[MUL]]
; CHECK-NEXT:    [[TMP25:%.*]] = fadd fast double [[TMP23]], [[TMP24]]
; CHECK-NEXT:    [[TMP26:%.*]] = insertvalue [3 x double] [[TMP22]], double [[TMP25]], 2
; CHECK-NEXT:    store double [[MUL2]], double* @global, align 8
; CHECK-NEXT:    store double [[TMP17]], double* %"global'ipa", align 8
; CHECK-NEXT:    store double [[TMP21]], double* %"global'ipa1", align 8
; CHECK-NEXT:    store double [[TMP25]], double* %"global'ipa2", align 8
; CHECK-NEXT:    ret [3 x double] [[TMP26]]
;
