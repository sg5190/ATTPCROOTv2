
/*********************************************************************
 *   Base class for Active Targets AtMap.h			     *
 *   Author: Y. Ayyad ayyadlim@frib.msu.edu            	             *
 *   Log: 2/22/2021 					             *
 *								     *
 *********************************************************************/

#ifndef ATMAP_H
#define ATMAP_H

#include <boost/multi_array.hpp>

#include "TObject.h"
#include "TROOT.h"
#include "TMath.h"

#include <unordered_map>
#include <map>
#include <vector>

class TH2Poly;
class TXMLNode;

// The definition of this struct, and the operator overloads have to
// be before AtMap where an unordered_map using this as a key is
// instatiated.
struct PadReference {
   Int_t cobo;
   Int_t asad;
   Int_t aget;
   Int_t ch;
};
bool operator<(const PadReference &l, const PadReference &r);
bool operator==(const PadReference &l, const PadReference &r);
namespace std {
template <>
struct hash<PadReference> {
   inline size_t operator()(const PadReference &x) const
   {
      return x.ch + x.aget * 100 + x.asad * 10000 + x.cobo * 1000000;
   }
};
} // namespace std

class AtMap : public TNamed {
public:
   enum InhibitType : char; // forward declare of enum

protected:
   typedef boost::multi_array<double, 3> multiarray;
   typedef multiarray::index index;

   multiarray AtPadCoord;
   multiarray *fAtPadCoordPtr;
   Int_t fPadInd;
   Bool_t kIsParsed;
   Bool_t kGUIMode;
   Bool_t kDebug;
   std::map<Int_t, AtMap::InhibitType> fIniPads;
   TCanvas *cAtTPCPlane;
   TH2Poly *hPlane;
   UInt_t fNumberPads;
   std::unordered_map<PadReference, int> AtTPCPadMap;
   std::map<int, PadReference> AtTPCPadMapInverse;
   std::unordered_map<PadReference, std::string> fAuxPadMap;
   std::map<int, int> AtTPCPadSize;

   void inhibitPad(Int_t padNum, AtMap::InhibitType type);

public:
   AtMap();
   ~AtMap();

   virtual void Dump() = 0;
   virtual void GenerateAtTpc() = 0;
   virtual std::vector<Float_t> CalcPadCenter(Int_t PadRef) = 0; // units mm
   virtual TH2Poly *GetAtTpcPlane() = 0;
   virtual Int_t BinToPad(Int_t binval) = 0;

   UInt_t GetNumPads() const { return fNumberPads; }

   Int_t GetPadNum(const PadReference &PadRef) const;
   multiarray GetPadCoordArr() { return AtPadCoord; }
   multiarray *GetPadCoord() { return fAtPadCoordPtr = &AtPadCoord; }

   Bool_t ParseXMLMap(Char_t const *xmlfile);
   void ParseMapList(TXMLNode *node);
   void ParseAtTPCMap(TXMLNode *node);
   Bool_t DumpAtTPCMap();
   PadReference GetPadRef(int padNum) const;
   bool AddAuxPad(const PadReference &ref, std::string auxName);
   bool IsAuxPad(const PadReference &ref) const;
   std::string GetAuxName(const PadReference &ref) const;

   inline void SetGUIMode() { kGUIMode = 1; }
   inline void SetDebugMode(Bool_t flag = true) { kDebug = flag; }
   Bool_t ParseInhibitMap(TString inimap, AtMap::InhibitType type);
   AtMap::InhibitType IsInhibited(Int_t PadNum);
   Int_t GetPadSize(int padNum);

   // The higher the number, the higher the priority
   // i.e. Adding a pad to the inhibit map with kTotal and kLowGain
   // will inhibit the pad. kLowGain and kXTalk will be kXTalk
   enum InhibitType : char { kNone = 0, kLowGain = 1, kXTalk = 2, kTotal = 3 };

   ClassDefOverride(AtMap, 4);
};

std::ostream &operator<<(std::ostream &os, const AtMap::InhibitType &t);
#endif
