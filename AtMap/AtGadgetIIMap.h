/*********************************************************************
 *   GADGETII Mapping Class				             *
 *   Author: Y. Ayyad   ayyadlim@frib.msu.edu        		     *
 *   Log: 2/26/2021					             *
 *								     *
 *********************************************************************/

#ifndef ATGADGETIIMAP_H
#define ATGADGETIIMAP_H

#include <boost/multi_array.hpp>

#include "AtMap.h"
#include "unordered_map"

class AtGadgetIIMap : public AtMap {

public:
   AtGadgetIIMap();
   ~AtGadgetIIMap();

   void Dump() override;                                      // pure virtual member
   void GenerateAtTpc() override;                             // pure virtual member
   std::vector<Float_t> CalcPadCenter(Int_t PadRef) override; // pure virtual member
   Int_t BinToPad(Int_t binval) override;                     // pure virtual member

   TH2Poly *GetAtTpcPlane() override; // virtual member

   void SetBinToPadMap();

private:
   std::unordered_map<Int_t, Int_t> fBinToPadTable;
   std::unordered_map<Int_t, Int_t>::iterator fBinToPadTableIt;

   ClassDefOverride(AtGadgetIIMap, 1);
};

#endif
