// Copyright (c) 2019 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;

public type BirEmitter object {

    private Package pkg;
    private TypeEmitter typeEmitter;
    private InstructionEmitter insEmitter;
    private TerminalEmitter termEmitter;
    private OperandEmitter opEmitter;

    public function __init (Package pkg){
        self.pkg = pkg;
        self.typeEmitter = new;
        self.insEmitter = new;
        self.termEmitter = new;
        self.opEmitter = new;
    }


    public function emitPackage() {
        println("################################# Begin bir program #################################");
        println();
        println("package ", self.pkg.org.value, "/", self.pkg.name.value, ";");
        // println("version - " + pkg.versionValue);
        
        println(); // empty line
        println("// Import Declarations");
        self.emitImports();
        println();
        println("// Type Definitions");
        self.emitTypeDefs();
        println();
        println("// Global Variables");
        self.emitGlobalVars();
        println();
        println("// Function Definitions");
        self.emitFunctions();
        println("################################## End bir program ##################################");
    }
    
    function emitImports() {
        foreach var i in self.pkg.importModules {
            println("import ", i.modOrg.value, "/", i.modName.value, " ", i.modVersion.value, ";");
        }
    }

    function emitTypeDefs() {
        foreach var bTypeDef in self.pkg.typeDefs {
            if (bTypeDef is TypeDef) {
                self.emitTypeDef(bTypeDef);
                println();
            }
        }
    }

    function emitTypeDef(TypeDef bTypeDef) {
        print(bTypeDef.visibility, " type ", bTypeDef.name.value, " ");
        self.typeEmitter.emitType(bTypeDef.typeValue);
        println(";");
    }

    function emitGlobalVars() {
        foreach var bGlobalVar in self.pkg.globalVars {
            if (bGlobalVar is GlobalVariableDcl) {
                print(bGlobalVar.visibility, " ");
                self.typeEmitter.emitType(bGlobalVar.typeValue);
                println(" ", bGlobalVar.name.value, ";");
            }
        }
    }

    function emitFunctions() {
        foreach var bFunction in self.pkg.functions {
            if (bFunction is Function) {
                self.emitFunction(bFunction);
                println();
            }
        }
    }

    function emitFunction(Function bFunction) {
        print(bFunction.visibility, " function ", bFunction.name.value, " ");
        self.typeEmitter.emitType(bFunction.typeValue);
        println(" {");
        foreach var v in bFunction.localVars {
            self.typeEmitter.emitType(v.typeValue, tabs = "\t");
            print(" ");
            if (v.name.value == "%0") {
                print("%ret");
            } else {
                print(v.name.value);
            }
            println("\t// ", v.kind);
        }
        println();// empty line
        foreach var b in bFunction.basicBlocks {
            if (b is BasicBlock) {
                self.emitBasicBlock(b, "\t");
                println();// empty line
            }
        }
        if (bFunction.errorEntries.length() > 0 ) {
            println("\tError Table \n\t\tBB\t|\terrorOp");
        }
        foreach var e in bFunction.errorEntries {
            if (e is ErrorEntry) {
                self.emitErrorEntry(e);
                println();// empty line
            }
        }
        println("}");
    }

    function emitBasicBlock(BasicBlock bBasicBlock, string tabs) {
        println(tabs, bBasicBlock.id.value, " {");
        foreach var ins in bBasicBlock.instructions {
            if (ins is Instruction) {
                self.insEmitter.emitIns(ins, tabs = tabs + "\t");
            }
        }
        self.termEmitter.emitTerminal(bBasicBlock.terminator, tabs = tabs + "\t");
        println(tabs, "}");
    }

    function emitErrorEntry(ErrorEntry errorEntry) {
        print("\t\t");
        print(errorEntry.trapBB.id.value);
        print("\t|\t");
        self.opEmitter.emitOp(errorEntry.errorOp);
    }
};

type InstructionEmitter object {
    private OperandEmitter opEmitter;
    private TypeEmitter typeEmitter;

    function __init() {
        self.opEmitter = new;
        self.typeEmitter = new;
    }

    function emitIns(Instruction ins, string tabs = "") {
        if (ins is FieldAccess) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            if (ins.kind == INS_KIND_MAP_STORE || ins.kind == INS_KIND_ARRAY_STORE) {
                print("[");
                self.opEmitter.emitOp(ins.keyOp);
                print("] = ", ins.kind, " ");
                self.opEmitter.emitOp(ins.rhsOp);
            } else {
                print(" = ", ins.kind, " ");
                self.opEmitter.emitOp(ins.rhsOp);
                print("[");
                self.opEmitter.emitOp(ins.keyOp);
                print("]");
            }
            println(";");
        } else if (ins is BinaryOp) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            print(" = ", ins.kind, " ");
            self.opEmitter.emitOp(ins.rhsOp1);
            print(" ");
            self.opEmitter.emitOp(ins.rhsOp2);
            println(";");
        } else if (ins is Move) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            print(" = ", ins.kind, " ");
            self.opEmitter.emitOp(ins.rhsOp);
            println(";");
        } else if (ins is ConstantLoad) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            print(" = ", ins.kind, " <");
            self.typeEmitter.emitType(ins.typeValue);
            println("> ", ins.value, ";");
        } else if (ins is NewArray) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            print(" = ", ins.kind, " [");
            self.opEmitter.emitOp(ins.sizeOp);
            println("];");
        } else if (ins is NewMap) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            print(" = ", ins.kind, " ");
            self.typeEmitter.emitType(ins.typeValue);
            println(";");
        } else if (ins is NewInstance) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            print(" = ", ins.kind, " ");
            println(ins.typeDef);
            //self.typeEmitter.emitType();
            println(";");
        } else if (ins is NewError) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            print(" = ", ins.kind, " ");
            self.opEmitter.emitOp(ins.reasonOp);
            print(" ");
            self.opEmitter.emitOp(ins.detailsOp);
            println(";");
        } else if (ins is TypeCast) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            print(" = ", ins.kind, " ");
            self.opEmitter.emitOp(ins.rhsOp);
            println(";");
        } else if (ins is IsLike) {
            print(tabs);
            self.opEmitter.emitOp(ins.lhsOp);
            print(" = ");
            self.opEmitter.emitOp(ins.rhsOp);
            print(" ", ins.kind, " ");
            self.typeEmitter.emitType(ins.typeValue);
            println(";");
        }
    }
};

type TerminalEmitter object {
    private OperandEmitter opEmitter;

    function __init() {
        self.opEmitter = new;
    }

    function emitTerminal(Terminator term, string tabs = "") {
        if (term is Call) {
            print(tabs);
            VarRef? lhsOp = term.lhsOp;
            if (lhsOp is VarRef) {
                self.opEmitter.emitOp(lhsOp);
                print(" = ");
            }
            print(term.pkgID.org, "/", term.pkgID.name, "::", term.pkgID.modVersion, ":", term.name.value, "(");
            int i = 0;
            foreach var arg in term.args {
                if (arg is VarRef) {
                    if (i != 0) {
                        print(", ");
                    }
                    self.opEmitter.emitOp(arg);
                    i = i + 1;
                }
            }
            print(") -> ", term.thenBB.id.value, ";");
        } else if (term is Branch) {
            print(tabs, "branch ");
            self.opEmitter.emitOp(term.op);
            println(" [true:", term.trueBB.id.value, ", false:", term.falseBB.id.value,"];");
        } else if (term is GOTO) {
            println(tabs, "goto ", term.targetBB.id.value, ";");
        } else if (term is Panic) {
            print(tabs, "panic ");
            self.opEmitter.emitOp(term.errorOp);
            print(";");
        } else { //if (term is Return) {
            println(tabs, "return;");
        }
    }
};

type OperandEmitter object {
    function emitOp(VarRef op, string tabs = "") {
        if (op.variableDcl.name.value == "%0") {
            print("%ret");
        } else {
            print(op.variableDcl.name.value);
        }
        // TODO add the rest, currently only have var ref
    }
};

type TypeEmitter object {

    function emitType(BType typeVal, string tabs = "") {
        if (typeVal is BTypeAny || typeVal is BTypeInt || typeVal is BTypeString || typeVal is BTypeBoolean
                || typeVal is BTypeFloat || typeVal is BTypeAnyData || typeVal is BTypeNone) {
            print(tabs, typeVal);
        } else if (typeVal is BRecordType) {
            self.emitRecordType(typeVal, tabs);
        } else if (typeVal is BObjectType) {
            self.emitObjectType(typeVal, tabs);
        } else if (typeVal is BInvokableType) {
            self.emitInvokableType(typeVal, tabs);
        } else if (typeVal is BArrayType) {
            self.emitArrayType(typeVal, tabs);
        } else if (typeVal is BUnionType) {
            self.emitUnionType(typeVal, tabs);
        } else if (typeVal is BTupleType) {
            self.emitTupleType(typeVal, tabs);
        } else if (typeVal is BMapType) {
            self.emitMapType(typeVal, tabs);
        } else if (typeVal is BFutureType) {
            self.emitFutureType(typeVal, tabs);
        } else if (typeVal is BTypeNil) {
            print("()");
        } else if (typeVal is BErrorType) {
            self.emitErrorType(typeVal, tabs);
        }
    }

    function emitRecordType(BRecordType bRecordType, string tabs) {
        print(tabs);
        if (bRecordType.sealed) {
            print("sealed ");
        }
        print("record { ");
        foreach var f in bRecordType.fields {
            self.emitType(f.typeValue, tabs = tabs + "\t");
            print(" ", f.name.value);
        }
        self.emitType(bRecordType.restFieldType, tabs = tabs + "\t");
        print("...");
        print(tabs, "}");
    }

    function emitObjectType(BObjectType bObjectType, string tabs) {
        print(tabs, "object {");
        foreach var f in bObjectType.fields {
            print(tabs + "\t", f.visibility, " ");
            self.emitType(f.typeValue);
            print(" ", f.name.value);
        }
        print(tabs, "}");
    }

    function emitInvokableType(BInvokableType bInvokableType, string tabs) {
        print(tabs, "(");
        // int pCount = bInvokableType.paramTypes.size(); 
        int i = 0;
        foreach var p in bInvokableType.paramTypes {
            if (i != 0) {
                print(", ");
            }
            self.emitType(p);
            i = i + 1;
        }
        print(") -> ");
        self.emitType(bInvokableType.retType);
    }

    function emitArrayType(BArrayType bArrayType, string tabs) {
        print(tabs);
        self.emitType(bArrayType.eType);
        print("<", bArrayType.state, ">");
        print("[]");
    }

    function emitUnionType(BUnionType bUnionType, string tabs) {
        int i = 0;
        string tabst = tabs;
        foreach var t in bUnionType.members {
            if (i != 0) {
                print(" | ");
                tabst = "";
            }
            self.emitType(t, tabs = tabst);
            i = i + 1;
        }
    }

    function emitTupleType(BTupleType bUnionType, string tabs) {
        int i = 0;
        print(tabs, "(");
        foreach var t in bUnionType.tupleTypes {
            if (i != 0) {
                print(", ");
            }
            self.emitType(t);
            i = i + 1;
        }
        print(")");
    }

    function emitMapType(BMapType bMapType, string tabs) {
        print(tabs, "map<");
        self.emitType(bMapType.constraint);
        print(">");
    }

    function emitFutureType(BFutureType bFutureType, string tabs) {
        print(tabs, "future<");
        self.emitType(bFutureType.returnType);
        print(">");
    }

    function emitErrorType(BErrorType bErrorType, string tabs) {
        print(tabs, "error{r-");
        self.emitType(bErrorType.reasonType);
        print(", d-");
        self.emitType(bErrorType.detailType);
        print("}");
    }
};


function println(any... vals) {
    io:println(...vals);
}

function print(any... vals) {
    io:print(...vals);
}