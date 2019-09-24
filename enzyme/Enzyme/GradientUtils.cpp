/*
 * GradientUtils.cpp - Gradient Utility data structures and functions
 *
 * Copyright (C) 2019 William S. Moses (enzyme@wsmoses.com) - All Rights Reserved
 *
 * For commercial use of this code please contact the author(s) above.
 *
 * For research use of the code please use the following citation.
 *
 * \misc{mosesenzyme,
    author = {William S. Moses, Tim Kaler},
    title = {Enzyme: LLVM Automatic Differentiation},
    year = {2019},
    howpublished = {\url{https://github.com/wsmoses/Enzyme/}},
    note = {commit xxxxxxx}
 */

#include "GradientUtils.h"

#include <llvm/Config/llvm-config.h>

#include "EnzymeLogic.h"

#include "FunctionUtils.h"

bool shouldRecompute(Value* val, const ValueToValueMapTy& available) {
  if (available.count(val)) return false;
  if (isa<Argument>(val) || isa<Constant>(val)) {
    return false;
  } else if (auto op = dyn_cast<CastInst>(val)) {
    return shouldRecompute(op->getOperand(0), available);
  } else if (isa<AllocaInst>(val)) {
    return true;
  } else if (auto op = dyn_cast<BinaryOperator>(val)) {
    bool a0 = shouldRecompute(op->getOperand(0), available);
    if (a0) {
        //llvm::errs() << "need recompute: " << *op->getOperand(0) << "\n";
    }
    bool a1 = shouldRecompute(op->getOperand(1), available);
    if (a1) {
        //llvm::errs() << "need recompute: " << *op->getOperand(1) << "\n";
    }
    return a0 || a1;
  } else if (auto op = dyn_cast<CmpInst>(val)) {
    return shouldRecompute(op->getOperand(0), available) || shouldRecompute(op->getOperand(1), available);
  } else if (auto op = dyn_cast<SelectInst>(val)) {
    return shouldRecompute(op->getOperand(0), available) || shouldRecompute(op->getOperand(1), available) || shouldRecompute(op->getOperand(2), available);
  } else if (auto load = dyn_cast<LoadInst>(val)) {
    Value* idx = load->getOperand(0);
    while (!isa<Argument>(idx)) {
      if (auto gep = dyn_cast<GetElementPtrInst>(idx)) {
        for(auto &a : gep->indices()) {
          if (shouldRecompute(a, available)) {
                        //llvm::errs() << "not recomputable: " << *a << "\n";
            return true;
          }
        }
        idx = gep->getPointerOperand();
      } else if(auto cast = dyn_cast<CastInst>(idx)) {
        idx = cast->getOperand(0);
      } else if(isa<CallInst>(idx)) {
            //} else if(auto call = dyn_cast<CallInst>(idx)) {
                //if (call->getCalledFunction()->getName() == "malloc")
                //    return false;
                //else
        {
                    //llvm::errs() << "unknown call " << *call << "\n";
          return true;
        }
      } else {
              //llvm::errs() << "not a gep " << *idx << "\n";
        return true;
      }
    }
    Argument* arg = cast<Argument>(idx);
    if (! ( arg->hasAttribute(Attribute::ReadOnly) || arg->hasAttribute(Attribute::ReadNone)) ) {
            //llvm::errs() << "argument " << *arg << " not marked read only\n";
      return true;
    }
    return false;
  } else if (auto phi = dyn_cast<PHINode>(val)) {
    if (phi->getNumIncomingValues () == 1) {
      bool b = shouldRecompute(phi->getIncomingValue(0) , available);
      if (b) {
            //llvm::errs() << "phi need recompute: " <<*phi->getIncomingValue(0) << "\n";
      }
      return b;
    }

    return true;
  } else if (auto op = dyn_cast<IntrinsicInst>(val)) {
    switch(op->getIntrinsicID()) {
      case Intrinsic::sin:
      case Intrinsic::cos:
      return false;
      return shouldRecompute(op->getOperand(0), available);
      default:
      return true;
    }
  }
  //llvm::errs() << "unknown inst " << *val << " unable to recompute\n";
  return true;
}

GradientUtils* GradientUtils::CreateFromClone(Function *todiff, AAResults &AA, TargetLibraryInfo &TLI, const std::set<unsigned> & constant_args, ReturnType returnValue, bool differentialReturn, llvm::Type* additionalArg) {
    assert(!todiff->empty());
    ValueToValueMapTy invertedPointers;
    SmallPtrSet<Value*,4> constants;
    SmallPtrSet<Value*,20> nonconstant;
    SmallPtrSet<Value*,2> returnvals;
    ValueToValueMapTy originalToNew;
    auto newFunc = CloneFunctionWithReturns(todiff, AA, TLI, invertedPointers, constant_args, constants, nonconstant, returnvals, /*returnValue*/returnValue, /*differentialReturn*/differentialReturn, "fakeaugmented_"+todiff->getName(), &originalToNew, /*diffeReturnArg*/false, additionalArg);
    auto res = new GradientUtils(newFunc, AA, TLI, invertedPointers, constants, nonconstant, returnvals, originalToNew);
    res->oldFunc = todiff;
    return res;
}

DiffeGradientUtils* DiffeGradientUtils::CreateFromClone(Function *todiff, AAResults &AA, TargetLibraryInfo &TLI, const std::set<unsigned> & constant_args, ReturnType returnValue, bool differentialReturn, Type* additionalArg) {
  assert(!todiff->empty());
  ValueToValueMapTy invertedPointers;
  SmallPtrSet<Value*,4> constants;
  SmallPtrSet<Value*,20> nonconstant;
  SmallPtrSet<Value*,2> returnvals;
  ValueToValueMapTy originalToNew;
  auto newFunc = CloneFunctionWithReturns(todiff, AA, TLI, invertedPointers, constant_args, constants, nonconstant, returnvals, returnValue, differentialReturn, "diffe"+todiff->getName(), &originalToNew, /*diffeReturnArg*/true, additionalArg);
  auto res = new DiffeGradientUtils(newFunc, AA, TLI, invertedPointers, constants, nonconstant, returnvals, originalToNew);
  res->oldFunc = todiff;
  return res;
}

Value* GradientUtils::invertPointerM(Value* val, IRBuilder<>& BuilderM) {
    if (isa<ConstantPointerNull>(val)) {
        return val;
    } else if (isa<UndefValue>(val)) {
        return val;
    } else if (auto cint = dyn_cast<ConstantInt>(val)) {
        if (cint->isZero()) return cint;
        //this is extra
        if (cint->isOne()) return cint;
    }

    if(isConstantValue(val)) {
        dumpSet(this->originalInstructions);
        if (auto arg = dyn_cast<Instruction>(val)) {
            llvm::errs() << *arg->getParent()->getParent() << "\n";
        }
        llvm::errs() << *val << "\n";
    }
    assert(!isConstantValue(val));

    auto M = BuilderM.GetInsertBlock()->getParent()->getParent();
    assert(val);

    if (invertedPointers.find(val) != invertedPointers.end()) {
        return lookupM(invertedPointers[val], BuilderM);
    }

    if (auto arg = dyn_cast<GlobalVariable>(val)) {
      if (!hasMetadata(arg, "enzyme_shadow")) {
          llvm::errs() << *arg << "\n";
          report_fatal_error("cannot compute with global variable that doesn't have marked shadow global");
      }
      auto md = arg->getMetadata("enzyme_shadow");
      if (!isa<MDTuple>(md)) {
          llvm::errs() << *arg << "\n";
          llvm::errs() << *md << "\n";
          report_fatal_error("cannot compute with global variable that doesn't have marked shadow global (metadata incorrect type)");
      }
      auto md2 = cast<MDTuple>(md);
      assert(md2->getNumOperands() == 1);
      auto gvemd = cast<ConstantAsMetadata>(md2->getOperand(0));
      auto cs = gvemd->getValue();
      return invertedPointers[val] = cs;
    } else if (auto fn = dyn_cast<Function>(val)) {
      //! Todo allow tape propagation
      auto newf = CreatePrimalAndGradient(fn, /*constant_args*/{}, TLI, AA, /*returnValue*/false, /*differentialReturn*/true, /*topLevel*/false, /*additionalArg*/nullptr);
      return BuilderM.CreatePointerCast(newf, fn->getType());
    } else if (auto arg = dyn_cast<CastInst>(val)) {
    auto result = BuilderM.CreateCast(arg->getOpcode(), invertPointerM(arg->getOperand(0), BuilderM), arg->getDestTy(), arg->getName()+"'ipc");
    return result;
    } else if (auto arg = dyn_cast<ExtractValueInst>(val)) {
    IRBuilder<> bb(arg);
    auto result = bb.CreateExtractValue(invertPointerM(arg->getOperand(0), bb), arg->getIndices(), arg->getName()+"'ipev");
    invertedPointers[arg] = result;
    return lookupM(invertedPointers[arg], BuilderM);
    } else if (auto arg = dyn_cast<InsertValueInst>(val)) {
    IRBuilder<> bb(arg);
    auto result = bb.CreateInsertValue(invertPointerM(arg->getOperand(0), bb), invertPointerM(arg->getOperand(1), bb), arg->getIndices(), arg->getName()+"'ipiv");
    invertedPointers[arg] = result;
    return lookupM(invertedPointers[arg], BuilderM);
    } else if (auto arg = dyn_cast<SelectInst>(val)) {
    IRBuilder<> bb(arg);
    auto result = bb.CreateSelect(arg->getCondition(), invertPointerM(arg->getTrueValue(), bb), invertPointerM(arg->getFalseValue(), bb), arg->getName()+"'ipse");
    invertedPointers[arg] = result;
    return lookupM(invertedPointers[arg], BuilderM);
    } else if (auto arg = dyn_cast<LoadInst>(val)) {
    IRBuilder <> bb(arg);
    auto li = bb.CreateLoad(invertPointerM(arg->getOperand(0), bb), arg->getName()+"'ipl");
    li->setAlignment(arg->getAlignment());
    return lookupM(li, BuilderM);
    } else if (auto arg = dyn_cast<GetElementPtrInst>(val)) {
      if (arg->getParent() == &arg->getParent()->getParent()->getEntryBlock()) {
        IRBuilder<> bb(arg);
        SmallVector<Value*,4> invertargs;
        for(auto &a: arg->indices()) {
            auto b = lookupM(a, bb);
            invertargs.push_back(b);
        }
        auto result = bb.CreateGEP(invertPointerM(arg->getPointerOperand(), bb), invertargs, arg->getName()+"'ipge");
        invertedPointers[arg] = result;
        return lookupM(invertedPointers[arg], BuilderM);
      }

    SmallVector<Value*,4> invertargs;
    for(auto &a: arg->indices()) {
        auto b = lookupM(a, BuilderM);
        invertargs.push_back(b);
    }
    auto result = BuilderM.CreateGEP(invertPointerM(arg->getPointerOperand(), BuilderM), invertargs, arg->getName()+"'ipg");
    return result;
    } else if (auto inst = dyn_cast<AllocaInst>(val)) {
        IRBuilder<> bb(inst);
        AllocaInst* antialloca = bb.CreateAlloca(inst->getAllocatedType(), inst->getType()->getPointerAddressSpace(), inst->getArraySize(), inst->getName()+"'ipa");
        invertedPointers[val] = antialloca;
        antialloca->setAlignment(inst->getAlignment());

        auto dst_arg = bb.CreateBitCast(antialloca,Type::getInt8PtrTy(val->getContext()));
        auto val_arg = ConstantInt::get(Type::getInt8Ty(val->getContext()), 0);
        auto len_arg = bb.CreateNUWMul(bb.CreateZExtOrTrunc(inst->getArraySize(),Type::getInt64Ty(val->getContext())), ConstantInt::get(Type::getInt64Ty(val->getContext()), M->getDataLayout().getTypeAllocSizeInBits(inst->getAllocatedType())/8 ) );
        auto volatile_arg = ConstantInt::getFalse(val->getContext());

#if LLVM_VERSION_MAJOR == 6
        auto align_arg = ConstantInt::get(Type::getInt32Ty(val->getContext()), antialloca->getAlignment());
        Value *args[] = { dst_arg, val_arg, len_arg, align_arg, volatile_arg };
#else
        Value *args[] = { dst_arg, val_arg, len_arg, volatile_arg };
#endif
        Type *tys[] = {dst_arg->getType(), len_arg->getType()};
        auto memset = cast<CallInst>(bb.CreateCall(Intrinsic::getDeclaration(M, Intrinsic::memset, tys), args));
        memset->addParamAttr(0, Attribute::getWithAlignment(inst->getContext(), inst->getAlignment()));
        memset->addParamAttr(0, Attribute::NonNull);
        return lookupM(invertedPointers[inst], BuilderM);
    } else if (auto phi = dyn_cast<PHINode>(val)) {
     std::map<Value*,std::set<BasicBlock*>> mapped;
     for(unsigned int i=0; i<phi->getNumIncomingValues(); i++) {
        mapped[phi->getIncomingValue(i)].insert(phi->getIncomingBlock(i));
     }

     if (false && mapped.size() == 1) {
        return invertPointerM(phi->getIncomingValue(0), BuilderM);
     }
#if 0
     else if (false && mapped.size() == 2) {
         IRBuilder <> bb(phi);
         auto which = bb.CreatePHI(Type::getInt1Ty(phi->getContext()), phi->getNumIncomingValues());
         //TODO this is not recursive

         int cnt = 0;
         Value* vals[2];
         for(auto v : mapped) {
            assert( cnt <= 1 );
            vals[cnt] = v.first;
            for (auto b : v.second) {
                which->addIncoming(ConstantInt::get(which->getType(), cnt), b);
            }
            cnt++;
         }

         auto which2 = lookupM(which, BuilderM);
         auto result = BuilderM.CreateSelect(which2, invertPointerM(vals[1], BuilderM), invertPointerM(vals[0], BuilderM));
         return result;
     }
#endif

     else {
         IRBuilder <> bb(phi);
         auto which = bb.CreatePHI(phi->getType(), phi->getNumIncomingValues());
         invertedPointers[val] = which;

         for(unsigned int i=0; i<phi->getNumIncomingValues(); i++) {
            IRBuilder <>pre(phi->getIncomingBlock(i)->getTerminator());
            which->addIncoming(invertPointerM(phi->getIncomingValue(i), pre), phi->getIncomingBlock(i));
         }

         return lookupM(which, BuilderM);
     }
    }
    assert(BuilderM.GetInsertBlock());
    assert(BuilderM.GetInsertBlock()->getParent());
    assert(val);
    llvm::errs() << "fn:" << *BuilderM.GetInsertBlock()->getParent() << "\nval=" << *val << "\n";
    for(auto z : invertedPointers) {
      llvm::errs() << "available inversion for " << *z.first << " of " << *z.second << "\n";
    }
    assert(0 && "cannot find deal with ptr that isnt arg");
    report_fatal_error("cannot find deal with ptr that isnt arg");
}

bool getContextM(BasicBlock *BB, LoopContext &loopContext, std::map<Loop*,LoopContext> &loopContexts, LoopInfo &LI,ScalarEvolution &SE,DominatorTree &DT, GradientUtils &gutils) {
    if (auto L = LI.getLoopFor(BB)) {
        if (loopContexts.find(L) != loopContexts.end()) {
            loopContext = loopContexts.find(L)->second;
            return true;
        }

        BasicBlock *Header = L->getHeader();
        assert(Header && "loop must have header");
        BasicBlock *Preheader = L->getLoopPreheader();
        assert(Preheader && "loop must have preheader");

        fake::SCEVExpander Exp(SE, BB->getParent()->getParent()->getDataLayout(), "enzyme");
        BasicBlock* ExitBlock = Exp.getExitBlock(L);

        // This contains the block that branches to the exit
        BasicBlock* Latch = Exp.getLatch(L, ExitBlock);

        // Note exitcount needs the true latch (e.g. the one that branches back to header)
        // tather than the latch that contains the branch (as we define latch)
        const SCEV *Limit = SE.getBackedgeTakenCount(L); //getExitCount(L, ExitckedgeTakenCountBlock); //L->getLoopLatch());

		SmallVector<PHINode*, 8> IVsToRemove;

		PHINode *CanonicalIV = nullptr;
		Value *LimitVar = nullptr;

        {

		if (SE.getCouldNotCompute() != Limit) {

        	CanonicalIV = canonicalizeIVs(Exp, Limit->getType(), L, DT, &gutils);
        	if (!CanonicalIV) {
                report_fatal_error("Couldn't get canonical IV.");
        	}

			LimitVar = Exp.expandCodeFor(Limit, CanonicalIV->getType(),
                                            Preheader->getTerminator());

			loopContext.dynamic = false;
		} else {
          //llvm::errs() << "Se has any info: " << SE.getBackedgeTakenInfo(L).hasAnyInfo() << "\n";
          llvm::errs() << "SE could not compute loop limit.\n";

		  IRBuilder <>B(&Header->front());
		  CanonicalIV = B.CreatePHI(Type::getInt64Ty(Header->getContext()), 1); //Header->getNumPredecessors());

		  for (BasicBlock *Pred : predecessors(Header)) {
              assert(Pred);
			  if (L->contains(Pred)) {
                  assert(Pred->getTerminator());
		          IRBuilder<> bld(Pred->getTerminator());
		          auto inc = bld.CreateNUWAdd(CanonicalIV, ConstantInt::get(CanonicalIV->getType(), 1));
		          CanonicalIV->addIncoming(inc, Pred);
              } else {
                  CanonicalIV->addIncoming(ConstantInt::get(CanonicalIV->getType(), 0), Pred);
			  }
		  }

		  B.SetInsertPoint(&ExitBlock->front());
		  LimitVar = B.CreatePHI(CanonicalIV->getType(), 1); // should be ExitBlock->getNumPredecessors());

		  for (BasicBlock *Pred : predecessors(ExitBlock)) {
    		if (LI.getLoopFor(Pred) == L)
		    	cast<PHINode>(LimitVar)->addIncoming(CanonicalIV, Pred);
			else
				cast<PHINode>(LimitVar)->addIncoming(ConstantInt::get(CanonicalIV->getType(), 0), Pred);
		  }
		  loopContext.dynamic = true;
		}

		// Remove Canonicalizable IV's
		{
		  for (BasicBlock::iterator II = Header->begin(); isa<PHINode>(II); ++II) {
			PHINode *PN = cast<PHINode>(II);
			if (PN == CanonicalIV) continue;
			if (!SE.isSCEVable(PN->getType())) continue;
			const SCEV *S = SE.getSCEV(PN);
			if (SE.getCouldNotCompute() == S) continue;
			Value *NewIV = Exp.expandCodeFor(S, S->getType(), CanonicalIV);
			if (NewIV == PN) {
				llvm::errs() << "TODO: odd case need to ensure replacement\n";
				continue;
			}
			PN->replaceAllUsesWith(NewIV);
			IVsToRemove.push_back(PN);
		  }
		}

        }

		for (PHINode *PN : IVsToRemove) {
		  gutils.erase(PN);
		}

        //if (SE.getCouldNotCompute() == Limit) {
        //Limit = SE.getMaxBackedgeTakenCount(L);
        //}
		assert(CanonicalIV);
		assert(LimitVar);
        loopContext.var = CanonicalIV;
        loopContext.limit = LimitVar;
        loopContext.antivar = PHINode::Create(CanonicalIV->getType(), CanonicalIV->getNumIncomingValues(), CanonicalIV->getName()+"'phi");
        loopContext.exit = ExitBlock;
        loopContext.latch = Latch;
        loopContext.preheader = Preheader;
		loopContext.header = Header;
        loopContext.parent = L->getParentLoop();

        loopContexts[L] = loopContext;
        return true;
    }
    return false;
}

Value* GradientUtils::lookupM(Value* val, IRBuilder<>& BuilderM, bool forceLookup) {
    if (isa<Constant>(val)) {
        return val;
    }
    if (isa<BasicBlock>(val)) {
        return val;
    }
    if (isa<Function>(val)) {
        return val;
    }
    if (isa<UndefValue>(val)) {
        return val;
    }
    if (isa<Argument>(val)) {
        return val;
    }
    if (isa<MetadataAsValue>(val)) {
        return val;
    }
    if (!isa<Instruction>(val)) {
        llvm::errs() << *val << "\n";
    }

    auto inst = cast<Instruction>(val);
    if (!forceLookup && inversionAllocs && inst->getParent() == inversionAllocs) {
        return val;
    }

    if (!forceLookup) {
        if (this->isOriginalBlock(*BuilderM.GetInsertBlock())) {
            if (BuilderM.GetInsertBlock()->size() && BuilderM.GetInsertPoint() != BuilderM.GetInsertBlock()->end()) {
                if (this->DT.dominates(inst, &*BuilderM.GetInsertPoint())) {
                    //llvm::errs() << "allowed " << *inst << "from domination\n";
                    return inst;
                }
            } else {
                if (this->DT.dominates(inst, BuilderM.GetInsertBlock())) {
                    //llvm::errs() << "allowed " << *inst << "from block domination\n";
                    return inst;
                }
            }
        }
        val = inst = fixLCSSA(inst, BuilderM);
    }

    assert(!this->isOriginalBlock(*BuilderM.GetInsertBlock()) || forceLookup);
    LoopContext lc;
    bool inLoop = getContext(inst->getParent(), lc);

    ValueToValueMapTy available;
    if (inLoop) {
        for(LoopContext idx = lc; ; getContext(idx.parent->getHeader(), idx)) {
          if (!isOriginalBlock(*BuilderM.GetInsertBlock())) {
            available[idx.var] = idx.antivar;
          } else {
            available[idx.var] = idx.var;
          }
          if (idx.parent == nullptr) break;
        }
    }

    if (!forceLookup) {
        if (!shouldRecompute(inst, available)) {
            auto op = unwrapM(inst, BuilderM, available, /*lookupIfAble*/true);
            assert(op);
            return op;
        }
        /*
        if (!inLoop) {
            if (!isOriginalBlock(*BuilderM.GetInsertBlock()) && inst->getParent() == BuilderM.GetInsertBlock());
            todo here/re
        }
        */
    }

    ensureLookupCached(inst);

    if (!inLoop) {
        auto result = BuilderM.CreateLoad(scopeMap[inst]);
        assert(result->getType() == inst->getType());
        return result;
    } else {
        SmallVector<Value*,3> indices;
        SmallVector<Value*,3> limits;
        for(LoopContext idx = lc; ; getContext(idx.parent->getHeader(), idx) ) {
          indices.push_back(unwrapM(idx.var, BuilderM, available, /*lookupIfAble*/false));
          if (idx.parent == nullptr) break;

          auto limitm1 = unwrapM(idx.limit, BuilderM, available, /*lookupIfAble*/true);
          assert(limitm1);
          auto lim = BuilderM.CreateNUWAdd(limitm1, ConstantInt::get(idx.limit->getType(), 1));
          if (limits.size() != 0) {
            lim = BuilderM.CreateNUWMul(lim, limits.back());
          }
          limits.push_back(lim);
        }

        Value* idx = nullptr;
        for(unsigned i=0; i<indices.size(); i++) {
          if (i == 0) {
            idx = indices[i];
          } else {
            idx = BuilderM.CreateNUWAdd(idx, BuilderM.CreateNUWMul(indices[i], limits[i-1]));
          }
        }

        Value* idxs[] = {idx};
        Value* tolookup = BuilderM.CreateLoad(scopeMap[inst]);
        auto result = BuilderM.CreateLoad(BuilderM.CreateGEP(tolookup, idxs));
        assert(result->getType() == inst->getType());
        return result;
    }
}

bool GradientUtils::getContext(BasicBlock* BB, LoopContext& loopContext) {
    return getContextM(BB, loopContext, this->loopContexts, this->LI, this->SE, this->DT, *this);
}