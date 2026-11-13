#include <cuda_runtime.h>
#include <cmath>
#include <vector>
#include <random>
#include <cstring>
#include <cstdio>
#include <algorithm>

// One shared shader for CUDA and the CPU fallback. Colors are accumulated as
// optical density: overlapping translucent pigments darken instead of turning gray.
#define HD __host__ __device__
struct V { float r,g,b; };
struct Dab { float x,y,rx,ry,angle,alpha,phase; V c; int kind; };
enum DabKind { Wash, Drop, Backrun, Rectangle, Triangle, Circle, Ring, Stroke, Panel, GridLine };
struct Settings { int width,height,seed,palette,style; float water,pigment,texture,splatter; };
HD float sat(float x) { return fminf(1.f,fmaxf(0.f,x)); }
HD float lerp(float a,float b,float t) { return a+(b-a)*t; }
HD unsigned hash(unsigned n) { n^=n>>16; n*=0x7feb352dU; n^=n>>15; n*=0x846ca68bU; return n^(n>>16); }
HD float rnd(int x,int y,int s) { return (hash((unsigned)x*374761393U+(unsigned)y*668265263U+(unsigned)s*1274126177U)&0xffffff)/16777215.f; }
HD float noise(float x,float y,int s) {
 int ix=(int)floorf(x),iy=(int)floorf(y); float a=x-ix,b=y-iy;
 a=a*a*(3-2*a); b=b*b*(3-2*b);
 return lerp(lerp(rnd(ix,iy,s),rnd(ix+1,iy,s),a),lerp(rnd(ix,iy+1,s),rnd(ix+1,iy+1,s),a),b);
}
HD float fbm(float x,float y,int s) { return .55f*noise(x,y,s)+.27f*noise(x*2.13f,y*2.13f,s+1)+.13f*noise(x*4.31f,y*4.31f,s+2)+.05f*noise(x*9.1f,y*9.1f,s+3); }
HD void pixel(int px,int py,unsigned char* out,Settings p,const Dab* d,int count) {
 float aspect=(float)p.width/p.height;
 float x=((px+.5f)/p.width-.5f)*aspect,y=(py+.5f)/p.height-.5f;
 float fiber=fbm(x*650,y*650,p.seed+401),grain=rnd(px,py,p.seed);
 float paper=1.f-p.texture*(.026f*fiber+.016f*grain);
 float r=paper,g=paper*.991f,b=paper*.966f;
 float warpX=(fbm(x*13+30,y*13,p.seed)-.5f)*.035f*p.water;
 float warpY=(fbm(x*13,y*13+30,p.seed+3)-.5f)*.035f*p.water;
 float nr=fbm(x*95,y*95,p.seed+73), fine=fbm(x*320,y*320,p.seed+95);
 for(int i=0;i<count;i++) {
  Dab a=d[i];
  float warpScale=a.kind==GridLine?.22f:(a.kind>=Rectangle?.9f:1.f);
  float dx=x+warpX*warpScale-a.x,dy=y+warpY*warpScale-a.y;
  if(fabsf(dx)>a.rx*1.8f+a.ry*1.8f || fabsf(dy)>a.rx*1.8f+a.ry*1.8f) continue;
  float cs=cosf(a.angle),sn=sinf(a.angle);
  float u=(dx*cs+dy*sn)/a.rx,v=(-dx*sn+dy*cs)/a.ry;
  float dist=sqrtf(u*u+v*v), theta=atan2f(v,u);
  float edge=1.f+.105f*sinf(theta*5+a.phase)+.065f*sinf(theta*9-a.phase*2)+.038f*sinf(theta*17+a.phase);
  edge+=(fbm(x*48+a.phase,y*48-a.phase,p.seed+i%11)-.5f)*(.33f+.18f*p.water);
  float q=dist/edge;
  float softness=a.kind==1?.06f:.12f+.19f*p.water;
  if(a.kind>=Rectangle) {
   float irregular=(fbm(x*67+a.phase,y*67,p.seed)-.5f)*(.16f+.12f*p.water);
   switch(a.kind) {
    case Rectangle: case Panel: case GridLine: q=fmaxf(fabsf(u),fabsf(v));break;
    case Triangle: q=fmaxf(-v, .5f*v+.8660254f*fabsf(u))/.65f;break;
    case Circle: q=dist;break;
    case Ring: q=fabsf(dist-.83f)/.17f;break;
    case Stroke: q=fmaxf(fabsf(u),fabsf(v+.44f*sinf(u*4+a.phase)+.19f*sinf(u*13-a.phase)));break;
   }
   q+=irregular;
   softness=a.kind==GridLine?.08f:.08f+.16f*p.water;
  }
  float cover=sat((1.f-q)/softness);
  if(cover<=0)continue;
  cover=cover*cover*(3-2*cover);
  float cloud=fbm(x*23+a.phase,y*23,p.seed+i%7);
  float density=(.38f+.85f*cloud)*(.9f+.2f*nr);
  // Capillary edge deposits and pigment trapped in paper valleys.
  float rim=expf(-powf((q-.91f)/.06f,2.f))*(.22f+.22f*(1-p.water));
  float granulation=1.f+p.texture*((fine-.5f)*.65f+(grain-.5f)*.16f);
  float alpha=a.alpha*cover*(density+rim)*granulation*p.pigment*.68f;
  if(p.style>=3) {
   // Torn, dry-brush gaps and interrupted ring marks, rather than pristine stamps.
   float dry=fbm(x*145+a.phase,y*145-a.phase,p.seed+i%13);
   if(a.kind>=Rectangle)alpha*=.28f+.72f*sat((dry-.2f)*2.7f);
   if(a.kind==Ring)alpha*=sat((sinf(theta*3+a.phase)+.65f)*2.5f);
  }
  // A pale cauliflower backrun within a wash, with a darker irregular perimeter.
  if(a.kind==2) alpha*=.35f+.8f*sat(fabsf(q-.6f)*3.f);
  r*=expf(-(1-a.c.r)*alpha*2.1f); g*=expf(-(1-a.c.g)*alpha*2.1f); b*=expf(-(1-a.c.b)*alpha*2.1f);
 }
 int o=(py*p.width+px)*4;
 out[o]=(unsigned char)(sat(b)*255);out[o+1]=(unsigned char)(sat(g)*255);out[o+2]=(unsigned char)(sat(r)*255);out[o+3]=255;
}
__global__ void renderKernel(unsigned char* out,Settings p,const Dab* d,int n) {
 int x=blockIdx.x*blockDim.x+threadIdx.x,y=blockIdx.y*blockDim.y+threadIdx.y;
 if(x<p.width&&y<p.height)pixel(x,y,out,p,d,n);
}
static const V palettes[][7]={
 {{1,.06f,.63f},{1,.62f,.08f},{.08f,.82f,.80f},{.66f,.38f,.88f},{1,.89f,.19f},{1,.31f,.66f},{.32f,.75f,.85f}},
 {{.2f,.55f,.19f},{.54f,.78f,.18f},{.04f,.46f,.30f},{.73f,.86f,.29f},{.35f,.73f,.57f},{.9f,.88f,.27f},{.12f,.57f,.42f}},
 {{.63f,.19f,.82f},{.84f,.35f,.84f},{.42f,.53f,.84f},{.25f,.83f,.78f},{.75f,.61f,.92f},{.51f,.31f,.69f},{.51f,.85f,.86f}},
 {{.04f,.44f,.68f},{.06f,.72f,.76f},{.22f,.65f,.76f},{.28f,.31f,.59f},{.41f,.81f,.68f},{.08f,.47f,.52f},{.67f,.85f,.86f}},
 {{.96f,.29f,.24f},{1,.64f,.14f},{.89f,.22f,.48f},{.63f,.29f,.65f},{.98f,.78f,.31f},{.95f,.46f,.40f},{.79f,.40f,.35f}},
 {{.15f,.24f,.49f},{.38f,.21f,.56f},{.08f,.53f,.60f},{.68f,.32f,.60f},{.34f,.44f,.69f},{.13f,.39f,.46f},{.65f,.57f,.78f}},
 {{.75f,.32f,.18f},{.84f,.61f,.29f},{.39f,.45f,.25f},{.57f,.30f,.27f},{.84f,.71f,.48f},{.28f,.46f,.42f},{.61f,.46f,.32f}},
 {{1,.08f,.25f},{1,.48f,.02f},{.96f,.85f,.04f},{.12f,.68f,.26f},{.04f,.62f,.86f},{.33f,.22f,.83f},{.81f,.11f,.66f}}
};
static std::vector<Dab> compose(Settings p) {
 std::mt19937 gen(p.seed); std::uniform_real_distribution<float> uni(0,1);
 auto R=[&](){return uni(gen);}; auto N=[&](){return (R()+R()+R()-1.5f)/1.5f;};
 std::vector<Dab> d; float asp=(float)p.width/p.height;
 auto add=[&](float x,float y,float rx,float ry,float a,int color,int kind=0,float angle=0.f){d.push_back({x,y,rx,ry,angle,a,R()*20,palettes[p.palette%8][color%7],kind});};
 auto scatter=[&](int count,float size) {
  for(int i=0;i<count;i++) {
   float s=.001f+powf(R(),3)*size;
   add((R()-.5f)*asp*.98f,(R()-.5f)*.98f,s,s*(.6f+R()),.18f+R()*.65f,int(R()*7),Drop,R()*6.28f);
  }
 };
 auto run=[&](float x,float y,int color,float length) {
  float lean=N()*.07f;
  for(int j=0;j<9;j++) {
   float t=(j+.5f)/9;
   add(x+lean*t+.007f*sinf(t*9),y+length*t,.003f*(1-t)+.0007f,length/12,.22f,color,Drop);
  }
  add(x+lean,y+length,.004f,.006f,.55f,color,Drop);
 };
 // Composition styles use the same pigment shader, but different deposit geometry.
 if(p.style==3) {
  for(int i=0;i<30;i++) {
   float x=(R()-.5f)*asp*.95f,y=(R()-.5f)*.92f;
   float size=.025f+powf(R(),1.4f)*.19f; int kind=Rectangle+i%4,color=int(R()*7);
   if(i%3==0)add(x+N()*.04f,y,size*1.2f,size*.8f,.18f,color,Wash,R()*6.28f);
   add(x,y,size,size*(.4f+R()),.4f+R()*.8f,color,kind,R()*6.28f);
   if(i%5==0)run(x,y,color,.05f+R()*.17f);
  }
  scatter((int)(85*p.splatter),.01f);
  return d;
 }
 if(p.style==4) {
  struct Cell {float l,t,r,b;};
  std::vector<Cell> cells={{-.44f*asp,-.43f,.44f*asp,.43f}};
  // Unequal orthogonal subdivisions leave quiet paper alongside colored panels.
  for(int pass=0;pass<11;pass++) {
   int chosen=-1; float biggest=0;
   for(int i=0;i<(int)cells.size();i++) {
    float area=(cells[i].r-cells[i].l)*(cells[i].b-cells[i].t);
    if(area>biggest){biggest=area;chosen=i;}
   }
   Cell c=cells[chosen]; bool vertical=(c.r-c.l)>(c.b-c.t)*(R()*.8f+.6f);
   float split=.28f+R()*.44f;
   if(vertical){float mid=lerp(c.l,c.r,split);cells[chosen]={c.l,c.t,mid,c.b};cells.push_back({mid,c.t,c.r,c.b});}
   else{float mid=lerp(c.t,c.b,split);cells[chosen]={c.l,c.t,c.r,mid};cells.push_back({c.l,mid,c.r,c.b});}
  }
  for(auto c:cells) {
   float cx=(c.l+c.r)*.5f,cy=(c.t+c.b)*.5f,rx=(c.r-c.l)*.5f,ry=(c.b-c.t)*.5f;
   if(R()<.76f) {
    int color=int(R()*7);
    add(cx+N()*.03f,cy+N()*.03f,rx*1.12f,ry*1.15f,1.f+R()*.6f,color,Panel,N()*.12f);
    // Pigment escapes the grid and leaves backruns and rivulets in the margins.
    for(int j=0;j<4;j++)add(cx+N()*rx*2,cy+N()*ry*2,rx*.6f,ry*.7f,.3f,color,Backrun,R()*6.28f);
    if(R()<.6f)run(cx+N()*rx,c.b-.015f,color,.06f+R()*.2f);
   }
  }
  for(auto c:cells) {
   float w=.0015f+R()*.005f;
   auto line=[&](float x,float y,float rx,float ry){
    if(R()<.2f)return;
    add(x+N()*.005f,y+N()*.005f,rx*(.87f+R()*.25f),ry*(.87f+R()*.25f),1.f+R()*.9f,0,GridLine,N()*.018f);
    d.back().c={.045f,.055f,.065f};
   };
   line(c.l,(c.t+c.b)*.5f,w,(c.b-c.t)*.5f+w);
   line(c.r,(c.t+c.b)*.5f,w,(c.b-c.t)*.5f+w);
   line((c.l+c.r)*.5f,c.t,(c.r-c.l)*.5f+w,w);
   line((c.l+c.r)*.5f,c.b,(c.r-c.l)*.5f+w,w);
  }
  for(int i=0;i<8;i++) {
   float x=(R()-.5f)*asp*.88f,y=(R()-.5f)*.86f;int color=int(R()*7);
   add(x,y,.04f+R()*.11f,.025f+R()*.065f,.35f,color,Drop,R()*6.28f);
   add(x,y,.08f+R()*.18f,.007f+R()*.016f,.2f,color,Stroke,N()*.5f);
  }
  scatter((int)(100*p.splatter),.018f);
  return d;
 }
 if(p.style==5) {
  for(int i=0;i<16;i++) {
   float x=(R()-.5f)*asp*.67f,y=(R()-.5f)*.68f;
   float rx=.08f+R()*.17f,ry=.055f+R()*.12f;
   int color=std::min(6,int(noise(x*6+12,y*6+12,p.seed)*7));
   float angle=R()*6.28f;
   add(x,y,rx,ry,.4f+R()*.45f,color,Drop,angle);
   add(x+N()*.05f,y+N()*.05f,rx*.85f,ry*.85f,.3f,color,Backrun,angle);
   for(int j=0;j<7;j++)add(x+N()*rx*1.7f,y+N()*ry*1.7f,rx*.4f,ry*.45f,.18f,color,j%2?Drop:Wash,angle);
   if(i%3==0)run(x,y,color,.1f+R()*.24f);
  }
  scatter((int)(110*p.splatter),.016f);
  return d;
 }
 if(p.style==6) {
  for(int i=0;i<25;i++) {
   float cx=(R()-.5f)*asp*.7f,cy=(R()-.5f)*.7f,angle=R()*6.28f;
   float length=.15f+R()*.45f,bend=.02f+R()*.12f,phase=R()*6.28f;
   float width=.001f+powf(R(),3)*.016f;int color=int(R()*7);
   float lastX=0,lastY=0;
   for(int j=0;j<=22;j++) {
    float t=j/22.f,u=(t-.5f)*length,v=bend*sinf(t*7+phase)+bend*.25f*sinf(t*19);
    float x=cx+u*cosf(angle)-v*sinf(angle),y=cy+u*sinf(angle)+v*cosf(angle);
    if(j&&R()>.08f){float dx=x-lastX,dy=y-lastY;
     add((x+lastX)*.5f,(y+lastY)*.5f,sqrtf(dx*dx+dy*dy)*.65f+width,width*(.3f+R()),.35f+R()*.6f,color,Drop,atan2f(dy,dx));}
    lastX=x;lastY=y;
   }
  }
  scatter((int)(80*p.splatter),.008f);
  return d;
 }
 if(p.style==7) {
  int bursts=11;
  for(int b=0;b<bursts;b++) {
   float cx=(R()-.5f)*asp*.72f,cy=(R()-.5f)*.7f;int color=int(R()*7);
   float splash=.025f+R()*.06f;
   add(cx,cy,splash,splash*(.6f+R()),.55f+R()*.65f,color,Drop,R()*6.28f);
   add(cx,cy,splash*1.4f,splash,.2f,color,Wash,R()*6.28f);
   int drops=65+(int)(p.splatter*100);
   for(int i=0;i<drops;i++) {
    float angle=R()*6.28f,radius=powf(R(),1.5f)*.48f;
    float size=.0008f+powf(R(),5)*.032f;
    add(cx+cosf(angle)*radius*asp,cy+sinf(angle)*radius,size,size*(.7f+R()*.6f),.35f+R()*.8f,color,Drop,R()*6.28f);
   }
   for(int i=0;i<9;i++) {
    float angle=R()*6.28f,length=.03f+R()*.18f;
    add(cx+cosf(angle)*length*.5f,cy+sinf(angle)*length*.5f,length,.001f+R()*.004f,.4f+R()*.4f,color,Stroke,angle);
   }
   if(b%2==0)run(cx,cy,color,.1f+R()*.23f);
  }
  return d;
 }
 bool field=p.style==2; int clusters=field?28:(p.style==1?11:18);
 for(int i=0;i<clusters;i++) {
  float x=field?N()*.87f*asp:N()*.26f*asp, y=field?N()*.87f:N()*.24f;
  int c=p.palette==7?int((x/asp+.5f)*7)%7:int(noise(x*6+12,y*6+12,p.seed+41)*7);
  c=std::max(0,std::min(6,c));
  float size=field?.14f+R()*.18f:.075f+R()*.105f;
  if(p.style==1){y-=.11f;size*=.75f;}
  for(int j=0;j<4;j++)add(x+N()*size*.85f,y+N()*size*.65f,size*(.6f+R()*.6f),size*(.4f+R()*.7f),.12f+R()*.15f,c,j==3?2:0,R()*6.28f);
 }
 if(!field) {
  for(int i=0;i<(int)(65*p.splatter);i++) {
   float a=R()*6.28f,rad=.12f+R()*.31f,sz=.0015f+powf(R(),3)*.014f;
   add(cosf(a)*rad*asp,sinf(a)*rad,sz,sz*(.7f+R()),.15f+R()*.35f,int(R()*7),1,R()*6.28f);
  }
  for(int i=0;i<(int)(9*p.splatter);i++) {
   float a=R()*6.28f; if(p.style==1)a=1.57f+N()*.25f;
   float length=.04f+R()*.14f;
   add(cosf(a)*(.16f+length*.4f)*asp,sinf(a)*(.16f+length*.4f),length,.002f+R()*.004f,.22f+R()*.2f,int(R()*7),1,a);
  }
 }
 return d;
}
extern "C" __declspec(dllexport) int wc_device(char* name,int length) {
 int count=0;cudaError_t e=cudaGetDeviceCount(&count);
 if(e!=cudaSuccess||count==0){snprintf(name,length,"CPU studio renderer (CUDA unavailable)");return 0;}
 cudaDeviceProp prop{};cudaGetDeviceProperties(&prop,0);snprintf(name,length,"CUDA · %s",prop.name);return 1;
}
extern "C" __declspec(dllexport) int wc_render(Settings p,unsigned char* output,char* error,int errorLength) {
 if(!output||p.width<1||p.height<1||p.width>8192||p.height>8192||p.palette<0||p.palette>7||p.style<0||p.style>7){snprintf(error,errorLength,"Invalid render settings");return -1;}
 auto d=compose(p);size_t bytes=(size_t)p.width*p.height*4;
 int count=0;cudaError_t e=cudaGetDeviceCount(&count);
 if(e==cudaSuccess&&count>0){
  unsigned char* pixels=nullptr;Dab* drops=nullptr;
  e=cudaMalloc(&pixels,bytes);
  if(e==cudaSuccess)e=cudaMalloc(&drops,d.size()*sizeof(Dab));
  if(e==cudaSuccess)e=cudaMemcpy(drops,d.data(),d.size()*sizeof(Dab),cudaMemcpyHostToDevice);
  if(e==cudaSuccess){renderKernel<<<dim3((p.width+15)/16,(p.height+15)/16),dim3(16,16)>>>(pixels,p,drops,(int)d.size());e=cudaGetLastError();}
  if(e==cudaSuccess)e=cudaMemcpy(output,pixels,bytes,cudaMemcpyDeviceToHost);
  cudaFree(pixels);cudaFree(drops);
  if(e==cudaSuccess)return 1;
  snprintf(error,errorLength,"CUDA: %s; used CPU fallback",cudaGetErrorString(e));
 }
 #pragma omp parallel for
 for(int y=0;y<p.height;y++)for(int x=0;x<p.width;x++)pixel(x,y,output,p,d.data(),(int)d.size());
 return 0;
}
