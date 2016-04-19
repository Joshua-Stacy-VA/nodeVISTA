HMPDJ00A ;SLC/MKB -- Patient demographics ;8/11/11  15:29
 ;;2.0;ENTERPRISE HEALTH MANAGEMENT PLATFORM;**1**;Sep 01, 2011;Build 49
 ;;Per VHA Directive 2004-038, this routine should not be modified.
 ;
 ; External References          DBIA#
 ; -------------------          -----
 ; ^AUPNVSIT                     2028
 ; ^DPT                         10035
 ; DGCV                          4156
 ; DGMSTAPI                      2716
 ; DGNTAPI                       3457
 ; DGPFAPI                       3860
 ; DGRPDB                        4807
 ; DIQ                           2056
 ; MPIF001                       2701
 ; SDUTL3                        1252
 ; VADPT                        10061
 ; VAFCTFU1                      2990
 ; VASITE                       10112
 ; XUAF4                         2171
 ;
 ; All tags expect DFN
 ; [HMPID, HMPSTART, HMPSTOP, HMPMAX, HMPTEXT not currently used here]
 ;
DPT1 ; -- Demographics
 N PAT D DPT1OD(.PAT)
 I $D(PAT)>9 D ADD^HMPDJ("PAT")
 Q
 ;
TEST(DFN) ; -- look at array values
 N PAT D DPT1OD(.PAT)
 ;ZW PAT
 Q
 ;
DPT1OD(PAT) ;
 N SYS S SYS=$$SITE^VASITE
 N $ES,$ET,ERRPAT,ERRMSG
 S $ET="D ERRHDLR^HMPDERRH",ERRPAT=DFN
 S ERRMSG="A problem occurred building the patient "_DFN_" demographic extract."
 D DEM,SVC,PRF,ATC,SUPP,ALIAS,FAC,PC,INPT
 D KVAR^VADPT
 Q
 ;
LKUP ; patient lookup data
 ; expects HMPSYS,DFN
 N X,X0
 S X0=^DPT(DFN,0),X=$P(X0,U)
 S PAT("fullName")=X
 S PAT("familyName")=$P(X,",")
 S PAT("givenNames")=$P(X,",",2,99)
 S X=$P(X0,U,2)
 S PAT("genderCode")="urn:va:pat-gender:"_X
 S PAT("genderName")=$$NAME(X,"gender")
 S PAT("localId")=DFN
 S PAT("pid")=HMPSYS_";"_DFN
 S PAT("uid")=$$SETUID^HMPUTILS("pt-select",DFN,DFN)
 S X=$$GETICN^MPIF001(DFN)
 S:X>0 PAT("icn")=X
 S PAT("ssn")=$P(X0,U,9)
 S PAT("birthDate")=$$JSONDT^HMPUTILS($P(X0,U,3))
 S PAT("sensitive")=$$BOOL($$SCREEN^DPTLK1(DFN))
 S X=$P($G(^DPT(DFN,.35)),U)
 S:X PAT("deceased")=$$JSONDT^HMPUTILS(X)
 I $D(PAT)>9 D ADD^HMPDJ("PAT")
 Q
 ;
DEM ;-demographic data
 N VADM,VA,VAERR,X,I
 S PAT("pid")=$$PID^HMPDJFS(DFN)
 S X=$$GETICN^MPIF001(DFN) S:X>1 PAT("icn")=X
 D DEM^VADPT S X=VADM(1),PAT("fullName")=X
 S PAT("familyName")=$P(X,","),PAT("givenNames")=$P(X,",",2,99)
 S PAT("ssn")=$P(VADM(2),U),PAT("localId")=DFN
 S PAT("uid")=$$SETUID^HMPUTILS("patient",DFN,DFN)
 S:$D(VA("BID")) PAT("briefId")=$E(X)_VA("BID")
 S X=+$P($P(VADM(3),U),"."),PAT("birthDate")=$$JSONDT^HMPUTILS(X)
 S X=$P(VADM(5),U),PAT("genderCode")="urn:va:pat-gender:"_X,PAT("genderName")=$$NAME(X,"gender")
 S X=+$P($P(VADM(6),U),".") S:X PAT("deceased")=$$JSONDT^HMPUTILS(X)
 S PAT("sensitive")=$$BOOL($$SCREEN^DPTLK1(DFN))
 ;S X=$$GET1^DIQ(38.1,DFN_",",2,"I") S:$L(X) PAT("sensitive")=$$BOOL(X)
 S X=+VADM(9) S:X PAT("religionCode")="urn:va:pat-religion:"_X,PAT("religionName")=$$NAME(X,"religion")
 S X=$P(VADM(10),U,2) I $L(X) D
 . S X=$E(X),X=$S(X="S":"L",X="N":"S",1:X)
 . S PAT("maritalStatusCode")="urn:va:pat-maritalStatus:"_X
 . S PAT("maritalStatusName")=$$NAME(X,"maritalStatus")
 I VADM(11) S I=0 F  S I=$O(VADM(11,I)) Q:I<1  D
 . S X=+VADM(11,I)
 . S PAT("ethnicity",X,"code")=$$GET1^DIQ(2.06,X_","_DFN_",",".01:3")
 I VADM(12) S I=0 F  S I=$O(VADM(12,I)) Q:I<1  D
 . S X=+VADM(12,I)
 . S PAT("race",X,"code")=$$GET1^DIQ(2.02,X_","_DFN_",",".01:3")
 Q
 ;
SVC ;-service data
 N VAEL,VASV,VAERR,X,Y,I,P,AO,IR,PGF,HNC,MST,CV,HMPSC
 D 7^VADPT
 S PAT("veteran")=$$BOOL(VAEL(4))
 S PAT("serviceConnected")=$$BOOL(+VAEL(3)) I VAEL(3) D
 . S PAT("scPercent")=+$P(VAEL(3),U,2)
 . D GETS^DIQ(2,DFN_",",".3731*",,"HMPSC")
 . S I="" F  S I=$O(HMPSC(2.05,I)) Q:I=""  D
 .. S PAT("scCondition",+I,"name")=HMPSC(2.05,I,.01)
 .. S PAT("scCondition",+I,"scPercent")=HMPSC(2.05,I,.02)
 S X=+$G(^DPT(DFN,"LR")) S:X PAT("lrdfn")=X
 I VAEL(9)]"" S PAT("meanStatus")=$P(VAEL(9),U,2)
 ;
 ; exposures
 S AO=VASV(2),IR=VASV(3)
 S PGF=VASV(11)!VASV(12)!VASV(13) ;OIF/OEF
 S X=$$GETCUR^DGNTAPI(DFN,"HNC"),X=+($G(HNC("STAT")))
 S HNC=$S(X=4:1,X=5:1,X=1:0,X=6:0,1:"")
 S X=$P($$GETSTAT^DGMSTAPI(DFN),U,2),MST=$S(X="Y":1,X="N":0,1:"")
 S X=$$CVEDT^DGCV(DFN),CV=$S(+X<0:"",+X=0:0,$P(X,U,3):1,1:0)
 S X=AO_U_IR_U_PGF_U_HNC_U_MST_U_CV
 F P=1:1:6 S I=$P(X,U,P),$P(X,U,P)=$S(I:"Yes",I=0:"No",1:"Unknown")
 S NM="agent-orange^ionizing-radiation^sw-asia^head-neck-cancer^mst^combat-vet"
 F P=1:1:6 S PAT("exposure",P,"uid")="urn:va:"_$P(NM,U,P)_":"_$E($P(X,U,P)),PAT("exposure",P,"name")=$P(X,U,P)
 ;
 ; rated disabilities [DGRPDB]
 N HMPDIS,DIS,NM,DX
 D RDIS^DGRPDB(DFN,.HMPDIS)
 S I=0 F  S I=$O(HMPDIS(I)) Q:I<1  D
 . S DIS=HMPDIS(I)
 . S NM=$$GET1^DIQ(31,+DIS_",",.01),DX=$$GET1^DIQ(31,+DIS_",",2)
 . S PAT("disability",+DX,"name")=NM
 . S PAT("disability",+DX,"disPercent")=$P(DIS,U,2)
 . S PAT("disability",+DX,"serviceConnected")=$$BOOL($P(DIS,U,3))
 Q
 ;
PRF ;-patient record flags
 N HMPF,I,N,X
 S X=$$GETACT^DGPFAPI(DFN,"HMPF")
 S I=0 F  S I=$O(HMPF(I)) Q:I<1  D
 . S PAT("patientRecordFlag",I,"assignmentStatus")="Active"
 . S PAT("patientRecordFlag",I,"assignTS")=$$JSONDT^HMPUTILS($P($G(HMPF(I,"ASSIGNDT")),U))
 . S PAT("patientRecordFlag",I,"approved")=$P($G(HMPF(I,"APPRVBY")),U,2)
 . S PAT("patientRecordFlag",I,"nextReviewDT")=$$JSONDT^HMPUTILS($P($G(HMPF(I,"REVIEWDT")),U))
 . S PAT("patientRecordFlag",I,"name")=$P($G(HMPF(I,"FLAG")),U,2)
 . S PAT("patientRecordFlag",I,"type")=$P($G(HMPF(I,"FLAGTYPE")),U,2)
 . S PAT("patientRecordFlag",I,"category")=$P($G(HMPF(I,"CATEGORY")),U,2)
 . S PAT("patientRecordFlag",I,"ownerSite")=$P($G(HMPF(I,"OWNER")),U,2)
 . S PAT("patientRecordFlag",I,"originatingSite")=$P($G(HMPF(I,"ORIGSITE")),U,2)
 . S N=1,X=$G(HMPF(I,"NARR",1,0))
 . F  S N=$O(HMPF(I,"NARR",N)) Q:N<1  S X=X_$C(13,10)_$G(HMPF(I,"NARR",N,0))
 . S PAT("patientRecordFlag",I,"text")=X
 S X=$$CWAD^ORQPT2(DFN)
 I X]"" S PAT("cwadf")=X
 I $D(PAT("patientRecordFlag")) S PAT("cwadf")=$G(PAT("cwadf"))_"F"
 Q
 ;
ATC ;-address & telecom
 N VAPA,CNT,X,I,P,NM
 ; VAPA("P")="" ;permanent address
 D ADD^VADPT S CNT=0 I $$VAPA(1,5) D
 . S CNT=CNT+1
 . D ADD(1,2,3,4,5,11,9,10)
 . S PAT("address",CNT,"use")=$S($L(VAPA(9)):"TMP",1:"H")
 I VAPA(12) D   ;confidential address
 . S CNT=CNT+1
 . D ADD(13,14,15,16,17,18,20,21)
 . S PAT("address",CNT,"use")="CONF"
 . S I=0 F  S I=$O(VAPA(22,I)) Q:I=""  S X=VAPA(22,I) D
 .. S PAT("address",CNT,"category",I,"name")=$P(X,U,2)
 .. S PAT("address",CNT,"category",I,"status")=$$BOOL($P(X,U,3))
 ; 
 ; X=home^cell^work phones
 S X=$$FORMAT(VAPA(8))_U_$$FORMAT($$GET1^DIQ(2,DFN_",",.134))_U_$$FORMAT($$GET1^DIQ(2,DFN_",",.132))
 S NM="H^MC^WP" F P=1:1:3 I $L($P(X,U,P)) D
 . S I=$P(NM,U,P),PAT("telecom",P,"use")=I
 . S PAT("telecom",P,"value")=$P(X,U,P)
 S X=$P($G(^DPT(DFN,.13)),U,3) S:X'="" PAT("email")=X
 I +$P($G(^DPT(DFN,.11)),U,16)>0 S PAT("badAddress")=$$GET1^DIQ(2,DFN_",",.121)
 Q
 ;
ADD(LINE1,LINE2,LINE3,CITY,STATE,ZIP,START,STOP) ; -- address set
 S:$L(VAPA(LINE1)) PAT("address",CNT,"line1")=VAPA(LINE1)
 S:$L(VAPA(LINE2)) PAT("address",CNT,"line2")=VAPA(LINE2)
 S:$L(VAPA(LINE3)) PAT("address",CNT,"line3")=VAPA(LINE3)
 S:$L(VAPA(CITY)) PAT("address",CNT,"city")=VAPA(CITY)
 S X=$P(VAPA(STATE),U) S:X PAT("address",CNT,"state")=$$GET1^DIQ(5,+X_",",1)
 S X=$P(VAPA(ZIP),U,2) S:$L(X) PAT("address",CNT,"zip")=X
 S X=+VAPA(START) S:X PAT("address",CNT,"start")=$$JSONDT^HMPUTILS(X)
 S X=+VAPA(STOP) S:X PAT("address",CNT,"end")=$$JSONDT^HMPUTILS(X)
 Q
 ;
VAPA(BEG,END) ; -- VAPA nodes have data?
 N I,Y S Y=0
 F I=BEG:1:END I $L($G(VAPA(I))) S Y=1 Q
 Q Y
 ;
SUPP ;-support contacts
 N VAOA,A,I,X,TYPE,S
 S S=0 F A="",1 K VAOA D
 . S:A VAOA("A")=A D OAD^VADPT Q:'$L($G(VAOA(9)))
 . S S=S+1,TYPE=$S(A=1:"ECON^Emergency Contact",1:"NOK^Next of Kin")
 . S PAT("contact",S,"typeCode")="urn:va:pat-contact:"_$P(TYPE,U)
 . S PAT("contact",S,"typeName")=$P(TYPE,U,2)
 . S:$L(VAOA(9)) PAT("contact",S,"name")=VAOA(9)
 . S:$L(VAOA(10)) PAT("contact",S,"relationship")=VAOA(10)
 . S:$L(VAOA(1)) PAT("contact",S,"address",1,"line1")=VAOA(1)
 . S:$L(VAOA(2)) PAT("contact",S,"address",1,"line2")=VAOA(2)
 . S:$L(VAOA(3)) PAT("contact",S,"address",1,"line3")=VAOA(3)
 . S:$L(VAOA(4)) PAT("contact",S,"address",1,"city")=VAOA(4)
 . S X=$P(VAOA(5),U) S:X PAT("contact",S,"address",1,"state")=$$GET1^DIQ(5,+X_",",1)
 . S X=$P(VAOA(11),U,2) S:$L(X) PAT("contact",S,"address",1,"zip")=X
 . S I=$S(A=1:.33011,1:.21011),X=$$FORMAT(VAOA(8))_U_U_$$FORMAT($$GET1^DIQ(2,DFN_",",I))
 . ; X=home^cell^work phones
 . S NM="H^MC^WP" F P=1:1:3 I $L($P(X,U,P)) D
 .. S I=$P(NM,U,P),PAT("contact",S,"telecom",P,"use")=I
 .. S PAT("contact",S,"telecom",P,"value")=$P(X,U,P)
 Q
 ;
ALIAS ;-other names used
 N I,X
 S I=0 F  S I=$O(^DPT(DFN,.01,I)) Q:I<1  S X=$G(^(I,0)) D
 . S PAT("alias",I,"fullName")=$P(X,U)
 Q
 ;
FAC ;-treating facilities [see FACLIST^ORWCIRN]
 N IFN S DFN=+$G(DFN) Q:DFN<1
 N HMPY,HOME,LAST,I,X,IEN,VASITE
 S X=$$ALL^VASITE ;VASITE(stn#)=stn# for all local
 I $L($T(TFL^VAFCTFU1)) D TFL^VAFCTFU1(.HMPY,DFN)
 S HOME=+$P($G(^DPT(DFN,"MPI")),U,3) ;home facility
 I $P($G(HMPY(1)),U)<0 D  ;not setup
 . S X=$O(^AUPNVSIT("AA",DFN,0)),LAST=$S(X:9999999-$P(X,"."),1:"")
 . S X=$$SITE^VASITE
 . S HMPY(1)=$P(X,U,3)_U_$P(X,U,2)_U_LAST_U_$$GET1^DIQ(4,+X_",",60)
 S I=0 F  S I=$O(HMPY(I)) Q:I<1  D
 . S X=HMPY(I) Q:$P(X,U)=""  ;unknown
 . S IEN=+$$IEN^XUAF4($P(X,U))
 . I +X=776!(+X=200) S $P(X,U,2)="DEPT. OF DEFENSE"
 . S PAT("facility",I,"code")=$P(X,U)    ;stn#
 . S PAT("facility",I,"name")=$P(X,U,2)  ;name
 . S:IEN=HOME PAT("facility",I,"homeSite")="true"
 . S:$L($P(X,U,3)) PAT("facility",I,"latestDate")=$$JSONDT^HMPUTILS($P($P(X,U,3),"."))
 . I $D(VASITE(+X)) D
 .. S PAT("facility",I,"localPatientId")=DFN
 .. S PAT("facility",I,"systemId")=HMPSYS
 Q
 ;
PC ;-primary care assignments
 D GETPATTM^HMPCRPC1(.PAT,DFN)
 Q
 N X S X=$$OUTPTPR^SDUTL3(DFN) I X D
 . S PAT("pcProviderUid")=$$SETUID^HMPUTILS("user",,+X)
 . S PAT("pcProviderName")=$P(X,U,2)
 S X=$$OUTPTTM^SDUTL3(DFN) I X D
 . S PAT("pcTeamUid")=$$SETUID^HMPUTILS("team",,+X)
 . S PAT("pcTeamName")=$P(X,U,2)
 Q
 ;
INPT ;-inpatient location
 N X,I,HL
 I $G(^DPT(DFN,.102)) D  ;current admission mvt
 . S X=$P($G(^DPT(DFN,.101)),U) S:X]"" PAT("roomBed")=X
 . S X=$P($G(^DPT(DFN,.1)),U) Q:X=""  S PAT("inpatientLocation")=X
 . S I=+$O(^DIC(42,"B",X,0)),HL=+$G(^DIC(42,I,44))
 . S X=$P($G(^SC(HL,0)),U,2) S:$L(X) PAT("shortInpatientLocation")=X
 Q
 ;
FORMAT(X) ; -- enforce (xxx)xxx-xxxx phone format
 S X=$G(X) I X?1"("3N1")"3N1"-"4N.E Q X
 N P,N,I,Y S P=""
 F I=1:1:$L(X) S N=$E(X,I) I N=+N S P=P_N
 S:$L(P)<10 P=$E("0000000000",1,10-$L(P))_P
 S Y=$S(P:"("_$E(P,1,3)_")"_$E(P,4,6)_"-"_$E(P,7,10),1:"")
 Q Y
 ;
NAME(CODE,SET) ; -- Return expanded name for code set
 N Y S Y="",CODE=$G(CODE)
 I $G(SET)="gender" S Y=$S(CODE="F":"Female",CODE="M":"Male",1:"Unknown")
 I $G(SET)="maritalStatus" S Y=$S(CODE="D":"Divorced",CODE="M":"Married",CODE="W":"Widowed",CODE="L":"Legally Separated",CODE="S":"Never Married",1:"Unknown")
 I $G(SET)="religion" S Y=$$GET1^DIQ(13,CODE_",",.01)
 Q Y
 ;
BOOL(X) ;
 I X>0 Q "true"
 S X=$E(X) I X="Y"!(X="y") Q "true"
 Q "false"