
#include <TInverseMap.h>

#include <fstream>
#include <iostream>
#include <cstdio>
#include <unistd.h>
#include <sstream>

#include <TSpline.h>

TInverseMap *TInverseMap::fInverseMap = 0;

TInverseMap::TInverseMap(const char *filename) : TNamed("InverseMap", filename)
{
   ReadMapFile(filename);
}

TInverseMap::TInverseMap() : TNamed("InverseMap", "multiInvMap") {}

TInverseMap::~TInverseMap() {}

TInverseMap *TInverseMap::Get(const char *filename)
{
   if (fInverseMap)
      return fInverseMap;
   if (strlen(filename) == 0 || access(filename, F_OK) == -1) {
      printf("no inverse map loaded and file \"%s\" not found.\n", filename);
      return 0;
   }
   fInverseMap = new TInverseMap(filename);
   return fInverseMap;
}

bool TInverseMap::ReadMapFile(const char *filename)
{
   std::string mapfile = filename;
   /*if(mapfile.length()==0)
     mapfile = TGRUTOptions::Get()->S800InverseMapFile();*/
   if (mapfile.length() == 0 || access(mapfile.c_str(), F_OK) == -1) {
      printf("no inverse map loaded and file \"%s\" not found.\n", mapfile.c_str());
      return false;
   }
   // static std::mutex inv_map_mutex;

   std::ifstream infile;
   infile.open(mapfile.c_str());
   std::string line;
   getline(infile, info);
   sscanf(info.c_str(), "S800 inverse map - Brho=%g - M=%d - Q=%d", &fBrho, &fMass, &fCharge);

   int par = 0;
   fsize = 0;
   while (getline(infile, line)) {
      if (line.find("----------") != std::string::npos)
         continue;
      if (line.find("COEFFICIENT") != std::string::npos) {
         par++;
         continue;
      }
      unsigned int index;
      InvMapRow invrow;
      std::stringstream ss(line);
      ss >> index;
      /*if((index-1) != fMap[par-1].size()) {
        //problems.
      }*/
      {
         std::string temp;
         ss >> temp;
         invrow.coefficient = std::atof(temp.c_str());
         fsize++;
      }
      //    ss >> invrow.coefficient;
      ss >> invrow.order;
      ss >> invrow.exp[0];
      ss >> invrow.exp[1];
      ss >> invrow.exp[2];
      ss >> invrow.exp[3];
      ss >> invrow.exp[4];
      ss >> invrow.exp[5];

      fMap[par - 1].push_back(invrow);

      // printf("%i\t%s\n",index,line.c_str());
   }
   return true;
}

bool TInverseMap::ReadMultiMapFile(std::vector<std::string> &mapfile_v)
{

   std::cout << "mapfile size : " << mapfile_v.size() << std::endl;
   fMap_v.clear();
   for (int i = 0; i < mapfile_v.size(); i++) {
      bool isRead = false;
      fMap.clear();
      isRead = ReadMapFile(mapfile_v.at(i).c_str());
      fMap_v.push_back(fMap);
      // fMapDist_v.push_back(0.1*(1+i));//change that, find a way to know the distance pivot-target for each map.
      std::cout << "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " << mapfile_v.at(i) << std::endl;
      if (!isRead)
         std::cout << "! Inv map file not read : " << mapfile_v.at(i) << std::endl;
   }

   std::vector<InvMapRow> invrow_v;
   std::vector<std::vector<double>> coeff_v;
   Int_t icoeff = 0;
   TSpline3 *spline[fsize];
   // TGraph *graph[fsize];

   if (fMap_v.size() > 0)
      for (int j = 0; j < fMap_v.at(0).size();
           j++) { // loop on par//assuming the first map has the same format as the following maps
         for (int k = 0; k < fMap_v.at(0).at(j).size(); k++) { // loop on coeff in par
            std::vector<double> buff_v;
            std::vector<InvMapRowS> blabla;
            InvMapRowS invrow_s;
            for (int i = 0; i < fMap_v.size(); i++) { // loop on maps
               // std::cout<<"mapcoeff : "<<i<<" "<<j<<" "<<k<<" "<<fMap_v.at(i).at(j).at(k).coefficient<<std::endl;
               buff_v.push_back((Double_t)fMap_v.at(i).at(j).at(k).coefficient);
               // std::cout<<"invrow : "<<j<<" "<<invrow_v.at(j).coefficient<<std::endl;
            }
            coeff_v.push_back(buff_v);
            char fname[20];
            sprintf(fname, "f_%d", icoeff);
            spline[icoeff] = new TSpline3(fname, &fMapDist_v[0], &buff_v[0], fMap_v.size());
            // graph[icoeff] = new TGraph(fMap_v.size(),&mapdist_v[0], &buff_v[0]);
            // std::cout<<"debug  : "<<j<<" "<<k<<" "<<fMap_v.size()<<" "<<fMapDist_v.back()<<"
            // "<<spline[icoeff]->Eval(0.35)<<std::endl;
            invrow_s.coefficient = spline[icoeff];
            invrow_s.order = fMap_v.at(0).at(j).at(k).order;
            invrow_s.exp[0] = fMap_v.at(0).at(j).at(k).exp[0];
            invrow_s.exp[1] = fMap_v.at(0).at(j).at(k).exp[1];
            invrow_s.exp[2] = fMap_v.at(0).at(j).at(k).exp[2];
            invrow_s.exp[3] = fMap_v.at(0).at(j).at(k).exp[3];
            invrow_s.exp[4] = fMap_v.at(0).at(j).at(k).exp[4];
            invrow_s.exp[5] = fMap_v.at(0).at(j).at(k).exp[5];
            fMap_s[j].push_back(invrow_s);
            icoeff++;
         }
         // fMap_s[j].push_back(invrow_s);
      }
   std::cout << "eval func " << fMap_s[0].at(0).coefficient->Eval(0.5) << " " << spline[0]->Eval(0.5) << std::endl;
   return true;
}

void TInverseMap::Print(Option_t *opt) const
{
   printf("%s\n", info.c_str());
   printf("\tBrho = %.04f\t", fBrho);
   printf("Mass = %i\t", fMass);
   printf("Q    = %i\n", fCharge);
   for (auto it1 : fMap) {
      printf("----------- par: %i ---------------\n", it1.first);
      int counter = 1;
      for (unsigned int i = 0; i < it1.second.size(); i++) {
         printf("\t%i\t%.04f\t\t%i\t%i %i %i %i %i %i\n", counter++, it1.second.at(i).coefficient,
                it1.second.at(i).order, it1.second.at(i).exp[0], it1.second.at(i).exp[1], it1.second.at(i).exp[2],
                it1.second.at(i).exp[3], it1.second.at(i).exp[4], it1.second.at(i).exp[5]);
      }
   }
}

// Parameter def.               |
//  0 == AtA                    |
//  1 == YTA                    |
//  2 == BTA                    |
//  3 == DTA                    |

// Input def.
//  0 == Crdc 0 -x in meters.   |
//  1 == - Afp in radians.      |
//  2 == Crdc 0 +y in meters.   |
//  3 == + Bfp in radians.      |
//  4 == 0;                     |
//  5 == 0;                     |

// S800 angles
// S800 system (looking dwnstream)
// positive ata: dispersive (aka: from x-axis) angle pointing down
// positive bta: none-dispersive (aka: from y-axis)  angle pointing right
// yta: y position in [m], along none-dispersive angle, positive right
//
// GRETINA:
// z: beamaxis
// x: down (=S800 neg. dispersive direction)
// Y: left
// Opening for gate valve points to the floor (x positive)
//
// We transform S800 angle into GRETINA.

float TInverseMap::Ata(int order, double xfp, double afp, double yfp, double bfp) const
{
   float input[6];
   input[0] = -xfp / 1000.0;
   input[1] = -afp;
   input[2] = yfp / 1000.0;
   input[3] = bfp;
   input[4] = 0.0;
   input[5] = 0.0;
   return MapCalc(order, 0, input);
}

float TInverseMap::Bta(int order, double xfp, double afp, double yfp, double bfp) const
{
   float input[6];
   input[0] = -xfp / 1000.0;
   input[1] = -afp;
   input[2] = yfp / 1000.0;
   input[3] = bfp;
   input[4] = 0.0;
   input[5] = 0.0;
   return MapCalc(order, 2, input);
}

float TInverseMap::Yta(int order, double xfp, double afp, double yfp, double bfp) const
{
   float input[6];
   input[0] = -xfp / 1000.0;
   input[1] = -afp;
   input[2] = yfp / 1000.0;
   input[3] = bfp;
   input[4] = 0.0;
   input[5] = 0.0;
   return MapCalc(order, 1, input);
}

float TInverseMap::Dta(int order, double xfp, double afp, double yfp, double bfp) const
{
   float input[6];
   input[0] = -xfp / 1000.0;
   input[1] = -afp;
   input[2] = yfp / 1000.0;
   input[3] = bfp;
   input[4] = 0.0;
   input[5] = 0.0;
   return MapCalc(order, 3, input);
}

float TInverseMap::Ata(int order, double xfp, double afp, double yfp, double bfp, double z)
{
   float input[6];
   input[0] = -xfp / 1000.0;
   input[1] = -afp;
   input[2] = yfp / 1000.0;
   input[3] = bfp;
   input[4] = 0.0;
   input[5] = 0.0;
   return MapCalc_s(order, 0, input, z);
}

float TInverseMap::Bta(int order, double xfp, double afp, double yfp, double bfp, double z)
{
   float input[6];
   input[0] = -xfp / 1000.0;
   input[1] = -afp;
   input[2] = yfp / 1000.0;
   input[3] = bfp;
   input[4] = 0.0;
   input[5] = 0.0;
   return MapCalc_s(order, 2, input, z);
}

float TInverseMap::Yta(int order, double xfp, double afp, double yfp, double bfp, double z)
{
   float input[6];
   input[0] = -xfp / 1000.0;
   input[1] = -afp;
   input[2] = yfp / 1000.0;
   input[3] = bfp;
   input[4] = 0.0;
   input[5] = 0.0;
   return MapCalc_s(order, 1, input, z);
}

float TInverseMap::Dta(int order, double xfp, double afp, double yfp, double bfp, double z)
{
   float input[6];
   input[0] = -xfp / 1000.0;
   input[1] = -afp;
   input[2] = yfp / 1000.0;
   input[3] = bfp;
   input[4] = 0.0;
   input[5] = 0.0;
   return MapCalc_s(order, 3, input, z);
}

/*
float TInverseMap::Ata(int order, const TS800 *s800) {
  float input[6];
  input[0]  = - s800->GetXFP() / 1000.0;
  input[1]  = - s800->GetAFP();
  input[2]  =   s800->GetYFP() / 1000.0;
  input[3]  =   s800->GetBFP();
  input[4]  =   0.0;
  input[5]  =   0.0;
  int par = 0; // AtA
  return MapCalc(order,par,input);
}

float TInverseMap::Bta(int order, const TS800 *s800) {
  float input[6];
  input[0]  = - s800->GetXFP() / 1000.0;
  input[1]  = - s800->GetAFP();
  input[2]  =   s800->GetYFP() / 1000.0;
  input[3]  =   s800->GetBFP();
  input[4]  =   0.0;
  input[5]  =   0.0;
  int par = 2; // BTA
  return MapCalc(order,par,input);
}

float TInverseMap::Yta(int order, const TS800 *s800) {
  float input[6];
  input[0]  = - s800->GetXFP() / 1000.0;
  input[1]  = - s800->GetAFP();
  input[2]  =   s800->GetYFP() / 1000.0;
  input[3]  =   s800->GetBFP();
  input[4]  =   0.0;
  input[5]  =   0.0;
  int par = 1; // YTA
  // *1000, because the map returns the value in meters.
  return MapCalc(order,par,input)*1000;
}

float TInverseMap::Dta(int order, const TS800 *s800) {
  float input[6];
  input[0]  = - s800->GetXFP() / 1000.0;
  input[1]  = - s800->GetAFP();
  input[2]  =   s800->GetYFP() / 1000.0;
  input[3]  =   s800->GetBFP();
  input[4]  =   0.0;
  input[5]  =   0.0;
  int par = 3; // DTA
  return MapCalc(order,par,input);
}*/

float TInverseMap::MapCalc(int order, int par, float *input) const
{
   float cumul = 0.0;
   float multiplicator = 0.0;
   std::vector<InvMapRow> vec = fMap.at(par);
   for (unsigned int x = 0; x < vec.size(); x++) {
      if (order < vec.at(x).order)
         break;
      multiplicator = 1.0;
      for (int y = 0; y < 6; y++) {
         if (vec.at(x).exp[y] != 0)
            multiplicator *= pow(input[y], vec.at(x).exp[y]);
      }
      cumul += multiplicator * vec.at(x).coefficient;
   }
   return cumul;
}

float TInverseMap::MapCalc_s(int order, int par, float *input, double z)
{
   float cumul = 0.0;
   float multiplicator = 0.0;
   std::vector<InvMapRowS> vec = fMap_s.at(par);
   for (unsigned int x = 0; x < vec.size(); x++) {
      if (order < vec.at(x).order)
         break;
      multiplicator = 1.0;
      for (int y = 0; y < 6; y++) {
         if (vec.at(x).exp[y] != 0)
            multiplicator *= pow(input[y], vec.at(x).exp[y]);
      }
      cumul += multiplicator * vec.at(x).coefficient->Eval(z);
   }

   return cumul;
}
