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
enum DabKind { Wash, Drop, Backrun, Rectangle, Triangle, Circle, Ring, Stroke, Panel, GridLine, YinDark, YinLight, FigureMale, FigureFemale, Star, GlowWash, EyeWhite, Leaf };
struct Settings { int width,height,seed,palette,style; float water,pigment,texture,splatter; };
struct Point {float x,y;};
struct FigureContours {Point male[512],female[512];int maleCount,femaleCount;};
// Continuous life-drawing contours. Cubic curves give anatomy a coherent line
// of action, instead of assembling a person out of circles and straight limbs.
static FigureContours makeFigures(int seed) {
 FigureContours result{};
 std::mt19937 poses((unsigned)seed^0x82ab491dU);
 auto variation=[&](){return (poses()%10000)/9999.f;};
 auto draw=[&](Point* points,int& count,bool female) {
  int pose=poses()%4,leftPose=poses()%2,legStart=0,legSplit=0,legEnd=0;
  Point pen={-.015f,-.91f};points[count++]=pen;
  auto C=[&](float ax,float ay,float bx,float by,float ex,float ey) {
   Point start=pen;
   for(int i=1;i<=7;i++){float t=i/7.f,s=1-t;
    points[count++]={s*s*s*start.x+3*s*s*t*ax+3*s*t*t*bx+t*t*t*ex,s*s*s*start.y+3*s*s*t*ay+3*s*t*t*by+t*t*t*ey};}
   pen={ex,ey};
  };
  if(pose==3) {
   // Seated life-study pose: torso arches above a bent knee and folded leg.
   C(.07f,-.93f,.12f,-.84f,.085f,-.76f);
   C(.06f,-.70f,.025f,-.7f,.04f,-.64f);
   C(.1f,-.59f,.2f,-.59f,.24f,-.52f);
   C(.30f,-.46f,.32f,-.30f,.34f,-.16f);
   C(.37f,-.02f,.42f,.14f,.45f,.26f);
   C(.47f,.30f,.42f,.33f,.39f,.28f);
   C(.34f,.18f,.28f,.04f,.26f,-.06f);
   C(.23f,-.17f,.20f,-.3f,.17f,-.37f);
   C(.18f,-.26f,.12f,-.17f,.13f,-.07f);
   C(.15f,.02f,.23f,.10f,.25f,.19f);
   C(.34f,.15f,.47f,.12f,.53f,.18f);
   C(.60f,.25f,.55f,.34f,.47f,.40f);
   C(.40f,.49f,.36f,.65f,.33f,.78f);
   C(.33f,.84f,.39f,.87f,.45f,.88f);
   C(.49f,.91f,.37f,.93f,.29f,.90f);
   C(.24f,.88f,.25f,.81f,.26f,.73f);
   C(.27f,.59f,.28f,.44f,.35f,.33f);
   C(.25f,.35f,.12f,.40f,.03f,.43f);
   C(-.05f,.50f,-.15f,.56f,-.30f,.59f);
   C(-.42f,.63f,-.53f,.61f,-.56f,.56f);
   C(-.58f,.52f,-.50f,.49f,-.45f,.48f);
   C(-.32f,.47f,-.23f,.44f,-.16f,.38f);
   C(-.24f,.29f,-.25f,.16f,-.21f,.07f);
   C(-.18f,-.04f,-.12f,-.13f,-.16f,-.25f);
   C(-.18f,-.31f,-.20f,-.35f,-.22f,-.39f);
   C(-.26f,-.23f,-.28f,-.04f,-.27f,.12f);
   C(-.26f,.19f,-.19f,.23f,-.15f,.28f);
   C(-.12f,.31f,-.14f,.34f,-.18f,.31f);
   C(-.28f,.27f,-.36f,.21f,-.36f,.12f);
   C(-.38f,-.03f,-.36f,-.36f,-.30f,-.48f);
   C(-.25f,-.57f,-.11f,-.57f,-.065f,-.64f);
   C(-.045f,-.69f,-.11f,-.74f,-.115f,-.8f);
   C(-.13f,-.87f,-.08f,-.92f,-.015f,-.91f);
   if(!female)for(int i=0;i<count;i++)if(points[i].y<-.08f&&points[i].y>-.6f)points[i].x*=1.13f;
  } else if(female) {
   C(.075f,-.925f,.12f,-.84f,.085f,-.755f); // crown, temple, jaw
   C(.075f,-.71f,.045f,-.7f,.045f,-.65f);
   C(.05f,-.60f,.12f,-.57f,.17f,-.55f);
   if(pose==0) {
   C(.23f,-.58f,.26f,-.70f,.30f,-.77f); // lifted upper arm
   C(.30f,-.81f,.19f,-.92f,.08f,-.94f);
   C(.035f,-.96f,-.025f,-.96f,-.048f,-.93f);
   C(-.03f,-.91f,.025f,-.91f,.06f,-.90f);
   C(.11f,-.87f,.20f,-.82f,.22f,-.77f);
   C(.20f,-.70f,.16f,-.62f,.13f,-.48f); // inner arm into ribcage
   } else if(pose==1) {
    C(.25f,-.55f,.36f,-.32f,.40f,-.17f);
    C(.40f,-.10f,.29f,.04f,.21f,.10f);
    C(.17f,.14f,.14f,.12f,.17f,.085f);
    C(.23f,.02f,.32f,-.11f,.32f,-.17f);
    C(.30f,-.26f,.24f,-.36f,.19f,-.42f);
    C(.17f,-.45f,.15f,-.47f,.13f,-.48f);
   } else {
    C(.25f,-.55f,.31f,-.39f,.31f,-.27f);
    C(.32f,-.12f,.34f,.05f,.33f,.22f);
    C(.33f,.28f,.29f,.32f,.27f,.285f);
    C(.25f,.25f,.28f,.20f,.275f,.15f);
    C(.26f,-.02f,.23f,-.22f,.20f,-.35f);
    C(.18f,-.42f,.15f,-.46f,.13f,-.48f);
   }
   C(.18f,-.44f,.20f,-.38f,.17f,-.32f); // bust and flank in silhouette
   C(.15f,-.24f,.09f,-.18f,.10f,-.10f);
   C(.11f,-.01f,.25f,.02f,.255f,.15f); // waist into full hip
   legStart=count;
   C(.26f,.27f,.19f,.36f,.14f,.47f);
   C(.09f,.61f,.005f,.72f,-.04f,.84f); // crossing leg outer calf
   C(-.055f,.89f,-.01f,.91f,.045f,.935f);
   C(.06f,.95f,-.035f,.96f,-.08f,.94f);
   C(-.12f,.92f,-.12f,.88f,-.095f,.82f);
   C(-.05f,.67f,.025f,.55f,.045f,.43f); // inner crossing leg
   C(.06f,.34f,.025f,.30f,.005f,.27f);
   legSplit=count;
   C(-.005f,.43f,-.045f,.55f,-.075f,.64f); // supporting leg
   C(-.11f,.76f,-.105f,.84f,-.11f,.91f);
   C(-.11f,.94f,-.08f,.95f,-.055f,.96f);
   C(-.07f,.98f,-.18f,.975f,-.19f,.95f);
   C(-.20f,.87f,-.185f,.76f,-.17f,.66f);
   C(-.15f,.54f,-.13f,.47f,-.16f,.38f);
   C(-.21f,.26f,-.245f,.19f,-.22f,.08f); // opposite hip
   legEnd=count;
   C(-.20f,-.01f,-.13f,-.08f,-.14f,-.18f);
   C(-.15f,-.24f,-.17f,-.32f,-.19f,-.37f);
   if(leftPose==0) {
   C(-.21f,-.32f,-.25f,-.20f,-.29f,-.13f); // hand-on-hip arm
   C(-.28f,-.08f,-.235f,-.025f,-.20f,.015f);
   C(-.18f,.035f,-.17f,.06f,-.20f,.06f);
   C(-.25f,.03f,-.36f,-.045f,-.36f,-.13f);
   C(-.34f,-.25f,-.30f,-.43f,-.24f,-.52f);
   C(-.20f,-.58f,-.08f,-.58f,-.065f,-.65f);
   } else {
    C(-.25f,-.37f,-.34f,-.54f,-.38f,-.63f);
    C(-.36f,-.72f,-.23f,-.87f,-.13f,-.94f);
    C(-.10f,-.97f,-.065f,-.97f,-.075f,-.94f);
    C(-.12f,-.88f,-.27f,-.69f,-.29f,-.63f);
    C(-.27f,-.59f,-.23f,-.55f,-.20f,-.53f);
    C(-.16f,-.58f,-.08f,-.58f,-.065f,-.65f);
   }
   C(-.06f,-.69f,-.11f,-.72f,-.115f,-.78f);
   C(-.14f,-.85f,-.10f,-.91f,-.015f,-.91f);
  } else {
   C(.07f,-.93f,.125f,-.85f,.095f,-.77f);
   C(.08f,-.72f,.045f,-.71f,.05f,-.66f);
   C(.065f,-.61f,.18f,-.61f,.255f,-.55f); // trapezius and deltoid
   if(pose==0) {
   C(.32f,-.51f,.34f,-.42f,.34f,-.34f);
   C(.37f,-.27f,.39f,-.19f,.37f,-.12f); // biceps, elbow
   C(.35f,-.05f,.31f,.03f,.26f,.10f);
   C(.25f,.15f,.22f,.19f,.20f,.16f);
   C(.18f,.14f,.205f,.08f,.22f,.04f);
   C(.25f,-.06f,.285f,-.14f,.28f,-.20f);
   C(.265f,-.24f,.24f,-.29f,.22f,-.34f);
   } else if(pose==1) {
    C(.34f,-.56f,.40f,-.70f,.43f,-.81f);
    C(.42f,-.87f,.25f,-.97f,.12f,-.98f);
    C(.06f,-1.f,.02f,-.98f,.05f,-.95f);
    C(.14f,-.91f,.30f,-.85f,.32f,-.80f);
    C(.31f,-.70f,.26f,-.64f,.24f,-.52f);
    C(.23f,-.44f,.235f,-.39f,.22f,-.34f);
   } else {
    C(.36f,-.52f,.45f,-.36f,.48f,-.20f);
    C(.47f,-.12f,.32f,.04f,.24f,.1f);
    C(.20f,.14f,.17f,.11f,.20f,.07f);
    C(.25f,.015f,.37f,-.13f,.37f,-.20f);
    C(.35f,-.27f,.29f,-.31f,.26f,-.36f);
    C(.25f,-.36f,.23f,-.35f,.22f,-.34f);
   }
   C(.205f,-.25f,.16f,-.15f,.145f,-.04f); // V torso, oblique
   C(.14f,.045f,.19f,.13f,.18f,.23f);
   legStart=count;
   C(.18f,.33f,.12f,.43f,.12f,.50f); // quadriceps
   C(.14f,.60f,.11f,.72f,.09f,.84f);
   C(.075f,.90f,.11f,.93f,.16f,.95f);
   C(.18f,.975f,.07f,.98f,.035f,.955f);
   C(.01f,.90f,.02f,.80f,.025f,.73f);
   C(.035f,.62f,.01f,.52f,-.015f,.43f);
   C(-.035f,.36f,-.045f,.30f,-.06f,.27f);
   legSplit=count;
   C(-.08f,.38f,-.13f,.46f,-.16f,.53f);
   C(-.18f,.63f,-.17f,.78f,-.18f,.89f);
   C(-.18f,.93f,-.14f,.955f,-.10f,.96f);
   C(-.10f,.99f,-.23f,.98f,-.25f,.95f);
   C(-.25f,.84f,-.235f,.73f,-.23f,.65f);
   C(-.245f,.54f,-.23f,.46f,-.21f,.37f);
   C(-.19f,.28f,-.215f,.19f,-.20f,.10f);
   legEnd=count;
   C(-.18f,.015f,-.14f,-.05f,-.16f,-.15f);
   C(-.18f,-.23f,-.21f,-.30f,-.23f,-.36f);
   if(leftPose==0) {
   C(-.255f,-.29f,-.28f,-.20f,-.27f,-.12f);
   C(-.26f,-.03f,-.21f,.05f,-.19f,.10f);
   C(-.17f,.145f,-.19f,.17f,-.22f,.14f);
   C(-.27f,.08f,-.34f,-.015f,-.35f,-.105f);
   C(-.38f,-.23f,-.36f,-.42f,-.31f,-.50f);
   C(-.27f,-.57f,-.20f,-.60f,-.12f,-.61f);
   C(-.055f,-.62f,-.055f,-.67f,-.065f,-.70f);
   } else {
    C(-.28f,-.40f,-.41f,-.58f,-.43f,-.70f);
    C(-.42f,-.79f,-.26f,-.93f,-.14f,-.97f);
    C(-.09f,-1.f,-.05f,-.98f,-.08f,-.94f);
    C(-.17f,-.87f,-.30f,-.72f,-.32f,-.69f);
    C(-.30f,-.63f,-.24f,-.58f,-.20f,-.57f);
    C(-.13f,-.59f,-.055f,-.67f,-.065f,-.70f);
   }
   C(-.11f,-.74f,-.14f,-.81f,-.10f,-.87f);
   C(-.08f,-.90f,-.045f,-.915f,-.015f,-.91f);
  }
  float bendA=(variation()-.5f)*.3f,bendB=(variation()-.5f)*.22f;
  float footA=(variation()-.5f)*.28f,footB=(variation()-.5f)*.25f;
  float hipSway=(variation()-.5f)*.12f,mirror=poses()%2?1.f:-1.f;
  for(int i=0;i<count;i++) {
   auto& a=points[i];
   if(i>=legStart&&i<legEnd) {
    float t=std::clamp((a.y-.24f)/.73f,0.f,1.f);
    bool front=i<legSplit;
    a.x+=(front?bendA:bendB)*sinf(t*3.1415927f)+(front?footA:footB)*t*t;
   }
   a.x+=hipSway*expf(-powf((a.y-.05f)/.32f,2));
   a.x*=mirror;
  }
 };
 draw(result.male,result.maleCount,false);draw(result.female,result.femaleCount,true);
 return result;
}
HD float contourDistance(float x,float y,const Point* points,int count) {
 float distance=100.f;bool inside=false;
 for(int i=0,j=count-1;i<count;j=i++) {
  Point a=points[i],b=points[j];float dx=b.x-a.x,dy=b.y-a.y;
  float t=fminf(1.f,fmaxf(0.f,((x-a.x)*dx+(y-a.y)*dy)/fmaxf(dx*dx+dy*dy,1e-9f)));
  float ex=x-a.x-t*dx,ey=y-a.y-t*dy;distance=fminf(distance,ex*ex+ey*ey);
  if((a.y>y)!=(b.y>y))if(x<(b.x-a.x)*(y-a.y)/(b.y-a.y)+a.x)inside=!inside;
 }
 return sqrtf(distance)*(inside?-1.f:1.f);
}
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
HD float capsule(float x,float y,float ax,float ay,float bx,float by,float radius) {
 float dx=bx-ax,dy=by-ay,t=sat(((x-ax)*dx+(y-ay)*dy)/(dx*dx+dy*dy));
 float px=x-ax-dx*t,py=y-ay-dy*t;return sqrtf(px*px+py*py)-radius;
}
HD void pixel(int px,int py,unsigned char* out,Settings p,const Dab* d,int count,const FigureContours* figures) {
 float aspect=(float)p.width/p.height;
 float x=((px+.5f)/p.width-.5f)*aspect,y=(py+.5f)/p.height-.5f;
 float fiber=fbm(x*650,y*650,p.seed+401),grain=rnd(px,py,p.seed);
 float paper=1.f-p.texture*(.026f*fiber+.016f*grain);
 float r=paper,g=paper*.991f,b=paper*.966f;
 float metalCoverage=0,metalR=0,metalG=0,metalB=0;
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
  if(p.style==16)softness=.30f+.3f*p.water;
  if(a.kind>=Rectangle) {
   float irregular=(fbm(x*67+a.phase,y*67,p.seed)-.5f)*(.16f+.12f*p.water);
   switch(a.kind) {
    case Rectangle: case Panel: case GridLine: q=fmaxf(fabsf(u),fabsf(v));break;
    case Triangle: q=fmaxf(-v, .5f*v+.8660254f*fabsf(u))/.65f;break;
    case Circle: case Star: q=dist;break;
    case EyeWhite: q=u*u+fabsf(v);break;
    case Leaf: q=u*u+powf(fabsf(v),.85f);break;
    case Ring: q=fabsf(dist-.83f)/.17f;break;
    case Stroke: q=fmaxf(fabsf(u),fabsf(v+.44f*sinf(u*4+a.phase)+.19f*sinf(u*13-a.phase)));break;
    case YinDark: case YinLight: {
     float halfY=v<0?v+.5f:v-.5f;
     float boundary=sqrtf(fmaxf(0.f,.25f-halfY*halfY))*(v<0?1.f:-1.f);
     float side=u-boundary;
     bool dark=a.kind==YinDark;
     float shape=fmaxf(dist-1.f,dark?side:-side);
     float top=sqrtf(u*u+(v+.5f)*(v+.5f));
     float bottom=sqrtf(u*u+(v-.5f)*(v-.5f));
     shape=fmaxf(shape,.145f-(dark?top:bottom));
     shape=fminf(shape,(dark?bottom:top)-.145f);
     q=1.f+shape;
     break;
    }
    case FigureMale: case FigureFemale: {
     bool female=a.kind==FigureFemale;
     float shape=contourDistance(u,v,female?figures->female:figures->male,female?figures->femaleCount:figures->maleCount);
     q=1.f+shape*4.f;
     softness=.09f+.13f*p.water;
     break;
    }
   }
   q+=irregular*(a.kind>=YinDark&&a.kind<=FigureFemale?.3f:1.f);
   if(a.kind<FigureMale||a.kind==Star)softness=a.kind==GridLine?.08f:.08f+.16f*p.water;
   if(p.style==16)softness=.28f+.3f*p.water;
   if(a.kind==YinDark||a.kind==YinLight)softness=.025f+.04f*p.water;
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
   if(a.kind>=Rectangle)alpha*=p.style>=8?(.68f+.32f*sat((dry-.2f)*2.7f)):(.28f+.72f*sat((dry-.2f)*2.7f));
   if(a.kind==Ring)alpha*=sat((sinf(theta*3+a.phase)+.65f)*2.5f);
  }
  // A pale cauliflower backrun within a wash, with a darker irregular perimeter.
  if(a.kind==2) alpha*=.35f+.8f*sat(fabsf(q-.6f)*3.f);
  if(p.palette==8&&a.kind!=Star&&a.kind!=EyeWhite) {
   bool warm=a.c.r>.6f&&a.c.g>.32f;
   bool silver=a.c.r>.45f&&fabsf(a.c.r-a.c.b)<.23f&&fabsf(a.c.r-a.c.g)<.2f;
   float deposit=(warm||silver)?sat(alpha*.8f):0.f;
   metalCoverage+=deposit;metalR+=a.c.r*deposit;metalG+=a.c.g*deposit;metalB+=a.c.b*deposit;
  }
  if(a.kind==FigureMale||a.kind==FigureFemale) {
   // Model the figure with translucent skin planes and broken contour ink.
   bool female=a.kind==FigureFemale;
   float edgeDistance=contourDistance(u,v,female?figures->female:figures->male,female?figures->femaleCount:figures->maleCount);
   float light=.77f+.12f*sinf(u*12+.5f)+.10f*fbm(u*7,v*7,p.seed);
   float chest=expf(-powf((fabsf(u)-.10f)/.09f,2)-powf((v+.40f)/.10f,2));
   float abdomen=expf(-powf(u/.12f,2)-powf((v+.12f)/.22f,2));
   float thigh=expf(-powf((fabsf(u)-.13f)/.10f,2)-powf((v-.36f)/.2f,2));
   light+=.16f*chest+.12f*thigh;
   light-=abdomen*(female?.08f:.12f)*( .6f+.4f*cosf(v*70));
   float outline=expf(-fabsf(edgeDistance)/.012f)*sat((cloud-.22f)*2.5f);
   light-=outline*.25f;
   if(!female)light-=.11f*expf(-powf(u/.018f,2))*abdomen;
   float cr=sat(a.c.r*light),cg=sat(a.c.g*light),cb=sat(a.c.b*light);
   // Abstract palette pigments model the planes; no fixed skin or hair colors.
   float cap=sat((-.83f-v+u*.15f)*16.f)*expf(-powf((u+.02f)/.12f,4));
   cr*=1-cap*.25f;cg*=1-cap*.25f;cb*=1-cap*.25f;
   float cheek=expf(-powf((u-.04f)/.03f,2)-powf((v+.76f)/.065f,2));
   cr*=1-.14f*cheek;cg*=1-.20f*cheek;cb*=1-.2f*cheek;
   float opacity=sat(alpha*1.9f);
   r=lerp(r,cr,opacity);g=lerp(g,cg,opacity);b=lerp(b,cb,opacity);
  }
  else if(a.kind==Star||a.kind==GlowWash||a.kind==EyeWhite){float light=sat(alpha*(a.kind==Star?1.7f:1.5f));r=lerp(r,a.c.r,light);g=lerp(g,a.c.g,light);b=lerp(b,a.c.b,light);}
  else{r*=expf(-(1-a.c.r)*alpha*2.1f); g*=expf(-(1-a.c.g)*alpha*2.1f); b*=expf(-(1-a.c.b)*alpha*2.1f);}
 }
 if(p.palette==8&&metalCoverage>.015f) {
  // Static metallic leaf: irregular foil islands, directional sheen, and fine
  // bright flakes sit in the pigment rather than covering untouched paper.
  float coverage=sat(metalCoverage*1.3f);
  float mr=metalR/metalCoverage,mg=metalG/metalCoverage,mb=metalB/metalCoverage;
  float islands=sat((fbm(x*92,y*92,p.seed+720)-.43f)*7.f);
  float facets=noise(x*650,y*650,p.seed+722);
  float sheen=powf(sat(.5f+.5f*sinf(x*32+y*19+fbm(x*27,y*27,p.seed+725)*7)),7);
  float flake=rnd((int)floorf(x*1000),(int)floorf(y*1000),p.seed+727);
  float fleck=sat((flake-.955f)/.045f);
  float reflectance=.40f+.65f*facets+.5f*sheen;
  float leaf=coverage*islands*(.28f+.25f*sheen+.3f*fleck);
  r=lerp(r,sat(mr*reflectance+.28f*fleck),sat(leaf));
  g=lerp(g,sat(mg*reflectance+.25f*fleck),sat(leaf));
  b=lerp(b,sat(mb*reflectance+.22f*fleck),sat(leaf));
  float grit=coverage*islands*fleck*.7f;
  r=lerp(r,1.f,grit);g=lerp(g,.95f,grit);b=lerp(b,.8f+.18f*mb,grit);
  // A few small four-point glints make the specular reflections read as sparkle.
  int gx=(int)floorf((x+aspect*.5f)*27),gy=(int)floorf((y+.5f)*27);
  if(rnd(gx,gy,p.seed+730)>.91f) {
   float cx=(gx+.15f+.7f*rnd(gx,gy,p.seed+731))/27-aspect*.5f;
   float cy=(gy+.15f+.7f*rnd(gx,gy,p.seed+732))/27-.5f;
   float dx=fabsf(x-cx),dy=fabsf(y-cy);
   float star=powf(sat(1-dx/.008f),3)*expf(-dy/.0006f)+powf(sat(1-dy/.008f),3)*expf(-dx/.0006f);
   star=sat(star*coverage*1.7f);
   r=lerp(r,1.f,star);g=lerp(g,.99f,star);b=lerp(b,.91f,star);
  }
 }
 if(p.palette==9){float gray=.2126f*r+.7152f*g+.0722f*b;r=g=b=gray;}
 if(p.palette==10){float tone=sat(.2126f*r+.7152f*g+.0722f*b);r=.13f+.87f*powf(tone,.88f);g=.06f+.91f*powf(tone,1.04f);b=.025f+.82f*powf(tone,1.32f);}
 int o=(py*p.width+px)*4;
 out[o]=(unsigned char)(sat(b)*255);out[o+1]=(unsigned char)(sat(g)*255);out[o+2]=(unsigned char)(sat(r)*255);out[o+3]=255;
}
__global__ void renderKernel(unsigned char* out,Settings p,const Dab* d,int n,const FigureContours* figures) {
 int x=blockIdx.x*blockDim.x+threadIdx.x,y=blockIdx.y*blockDim.y+threadIdx.y;
 if(x<p.width&&y<p.height)pixel(x,y,out,p,d,n,figures);
}
static const V palettes[][7]={
 {{1,.06f,.63f},{1,.62f,.08f},{.08f,.82f,.80f},{.66f,.38f,.88f},{1,.89f,.19f},{1,.31f,.66f},{.32f,.75f,.85f}},
 {{.2f,.55f,.19f},{.54f,.78f,.18f},{.04f,.46f,.30f},{.73f,.86f,.29f},{.35f,.73f,.57f},{.9f,.88f,.27f},{.12f,.57f,.42f}},
 {{.63f,.19f,.82f},{.84f,.35f,.84f},{.42f,.53f,.84f},{.25f,.83f,.78f},{.75f,.61f,.92f},{.51f,.31f,.69f},{.51f,.85f,.86f}},
 {{.04f,.44f,.68f},{.06f,.72f,.76f},{.22f,.65f,.76f},{.28f,.31f,.59f},{.41f,.81f,.68f},{.08f,.47f,.52f},{.67f,.85f,.86f}},
 {{.96f,.29f,.24f},{1,.64f,.14f},{.89f,.22f,.48f},{.63f,.29f,.65f},{.98f,.78f,.31f},{.95f,.46f,.40f},{.79f,.40f,.35f}},
 {{.15f,.24f,.49f},{.38f,.21f,.56f},{.08f,.53f,.60f},{.68f,.32f,.60f},{.34f,.44f,.69f},{.13f,.39f,.46f},{.65f,.57f,.78f}},
 {{.75f,.32f,.18f},{.84f,.61f,.29f},{.39f,.45f,.25f},{.57f,.30f,.27f},{.84f,.71f,.48f},{.28f,.46f,.42f},{.61f,.46f,.32f}},
 {{1,.08f,.25f},{1,.48f,.02f},{.96f,.85f,.04f},{.12f,.68f,.26f},{.04f,.62f,.86f},{.33f,.22f,.83f},{.81f,.11f,.66f}},
 {{.94f,.70f,.21f},{.70f,.77f,.83f},{.84f,.43f,.23f},{.91f,.61f,.54f},{.10f,.49f,.48f},{.39f,.23f,.49f},{.12f,.17f,.22f}},
 {{.10f,.10f,.10f},{.23f,.23f,.23f},{.37f,.37f,.37f},{.50f,.50f,.50f},{.65f,.65f,.65f},{.78f,.78f,.78f},{.90f,.90f,.90f}},
 {{.24f,.15f,.08f},{.39f,.25f,.13f},{.52f,.36f,.20f},{.66f,.49f,.29f},{.76f,.62f,.40f},{.86f,.74f,.53f},{.93f,.85f,.68f}}
};
static std::vector<Dab> compose(Settings p) {
 std::mt19937 gen(p.seed); std::uniform_real_distribution<float> uni(0,1);
 auto R=[&](){return uni(gen);}; auto N=[&](){return (R()+R()+R()-1.5f)/1.5f;};
 std::vector<Dab> d; float asp=(float)p.width/p.height;
 auto add=[&](float x,float y,float rx,float ry,float a,int color,int kind=0,float angle=0.f){d.push_back({x,y,rx,ry,angle,a,R()*20,palettes[p.palette][color%7],kind});};
 // Paint the entire sheet before laying in the newer composition themes.
 // A wide transparent ground reaches every corner; drifting glazes add depth.
 if(p.style>=3) {
  int ground=int(R()*7),accent=(ground+2+int(R()*3))%7;
  add(0,0,asp*2.5f,2.5f,.22f,ground,Wash);
  for(int i=0;i<21;i++) {
   float x=(R()-.5f)*asp*1.25f,y=(R()-.5f)*1.2f;
   float size=.18f+R()*.28f;
   int color=i%4==0?accent:ground;
   add(x,y,size*(.8f+R()),size,.07f+R()*.11f,color,i%3==0?Backrun:Wash,R()*6.28f);
  }
 }
 const size_t backgroundCount=d.size();
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
 auto mark=[&](float x1,float y1,float x2,float y2,float width,float alpha,int color) {
  float dx=x2-x1,dy=y2-y1;
  add((x1+x2)*.5f,(y1+y2)*.5f,sqrtf(dx*dx+dy*dy)*.53f+width,width,alpha,color,Drop,atan2f(dy,dx));
 };
 auto transform=[&](float rotation,float tx,float ty) {
  for(size_t i=backgroundCount;i<d.size();i++){auto& a=d[i];float x=a.x,y=a.y;a.x=x*cosf(rotation)-y*sinf(rotation)+tx;a.y=x*sinf(rotation)+y*cosf(rotation)+ty;a.angle+=rotation;}
 };
 if(p.style==18) {
  int count=5+int(R()*7),base=int(R()*7);bool bouquet=R()<.6f;
  for(int f=0;f<count;f++) {
   float x=(R()-.5f)*asp*(bouquet?.65f:.85f),y=(R()-.5f)*(bouquet?.5f:.8f)-.04f;
   float size=.035f+R()*.055f,rootX=bouquet?N()*asp*.07f:x+N()*.12f;
   int color=(base+f+int(R()*3))%7,stemColor=(base+3)%7;
   float lastX=rootX,lastY=.45f;
   for(int j=1;j<=12;j++) {
    float t=j/12.f,sx=lerp(rootX,x,t)+sinf(t*3.14f)*N()*.015f,sy=lerp(.45f,y,t);
    mark(lastX,lastY,sx,sy,.0016f,.6f,stemColor);d.back().c.r*=.5f;d.back().c.g*=.65f;d.back().c.b*=.5f;
    if(j==4||j==7)for(int side=-1;side<=1;side+=2) {
     float angle=atan2f(y-.45f,x-rootX)+side*.95f,l=.025f+R()*.02f;
     add(sx+cosf(angle)*l,sy+sinf(angle)*l,l,l*.4f,.6f,stemColor,Leaf,angle);
    }
    lastX=sx;lastY=sy;
   }
   int petals=5+int(R()*9),layers=1+int(R()*3);float rotation=R()*6.28f;
   // Loose translucent underpainting lets petal edges bleed into one another.
   add(x,y,size*1.4f,size*1.3f,.16f,color,Wash,rotation);
   for(int layer=0;layer<layers;layer++)for(int petal=0;petal<petals;petal++) {
    float angle=rotation+petal*6.2831853f/petals+layer*.33f+N()*.16f;
    float reach=size*(.55f-layer*.1f),length=size*(.57f-layer*.09f);
    add(x+cosf(angle)*reach,y+sinf(angle)*reach,length,length*(.35f+R()*.35f),.4f+R()*.45f,(color+layer)%7,Drop,angle);
   }
   add(x,y,size*.23f,size*.23f,1.2f,(color+3)%7,Circle);
   for(int k=0;k<18;k++) {
    float a=R()*6.28f,r=sqrtf(R())*size*.2f;
    add(x+cosf(a)*r,y+sinf(a)*r,.0012f+R()*.001f,.0014f,.9f,4,Drop);d.back().c={1.f,.8f,.16f};
   }
  }
  scatter((int)(75*p.splatter),.008f);
  return d;
 }
 if(p.style==17) {
  int stems=3+int(R()*4),base=int(R()*7);
  auto ink=[&](float x1,float y1,float x2,float y2,float width,float alpha,int color) {
   mark(x1,y1,x2,y2,width,alpha,color);
   d.back().c.r*=.5f;d.back().c.g*=.6f;d.back().c.b*=.5f;
  };
  auto leaf=[&](float x,float y,float length,float width,float angle,int color) {
   float cx=x+cosf(angle)*length,cy=y+sinf(angle)*length;
   add(cx,cy,length,width,.7f+R()*.5f,color,Leaf,angle);
   add(cx+N()*.008f,cy+N()*.008f,length*.9f,width*1.1f,.2f,(color+1)%7,Leaf,angle+.03f);
   ink(x,y,x+cosf(angle)*length*1.9f,y+sinf(angle)*length*1.9f,.0008f,.48f,color);
   for(int j=1;j<5;j++) {
    float t=j/5.f,u=length*2*t,v=width*(1-powf(t*2-1,2))*.78f;
    for(int side=-1;side<=1;side+=2) {
     float px=x+cosf(angle)*u,py=y+sinf(angle)*u;
     ink(px,py,px+cosf(angle)*length*.15f-sinf(angle)*v*side,py+sinf(angle)*length*.15f+cosf(angle)*v*side,.0005f,.3f,color);
    }
   }
  };
  for(int stem=0;stem<stems;stem++) {
   float startX=(R()-.5f)*asp*.65f,startY=.4f+N()*.04f;
   float endX=(R()-.5f)*asp*.75f,endY=-.30f-R()*.15f,bend=N()*.13f;
   float lastX=startX,lastY=startY;
   int nodes=7+int(R()*5),color=(base+stem*2)%7;
   for(int j=1;j<=nodes;j++) {
    float t=j/(float)nodes,x=lerp(startX,endX,t)+bend*sinf(t*3.14f),y=lerp(startY,endY,t);
    ink(lastX,lastY,x,y,.0012f+.0014f*(1-t),.75f,color);
    float direction=atan2f(y-lastY,x-lastX);
    for(int side=-1;side<=1;side+=2) {
     if(R()<.14f)continue;
     float a=direction+side*(.65f+R()*.55f);
     float length=(.035f+R()*.04f)*(1.2f-.45f*t);
     leaf(x+N()*.008f,y+N()*.012f,length,length*(.3f+R()*.3f),a,(color+int(R()*3))%7);
    }
    lastX=x;lastY=y;
   }
   leaf(lastX,lastY,.04f,.016f,atan2f(endY-startY,endX-startX),color);
  }
  for(int i=0;i<9;i++)leaf((R()-.5f)*asp*.93f,(R()-.5f)*.9f,.025f+R()*.025f,.01f+R()*.012f,R()*6.28f,(base+i)%7);
  scatter((int)(65*p.splatter),.007f);
  return d;
 }
 if(p.style==15) {
  int nx=4+int(R()*3),ny=4+int(R()*3),base=int(R()*7);
  float w=asp*.9f/nx,h=.9f/ny;
  for(int iy=0;iy<ny;iy++)for(int ix=0;ix<nx;ix++) {
   float x=(ix-(nx-1)*.5f)*w,y=(iy-(ny-1)*.5f)*h;int c=(base+ix+iy*2)%7;
   int pattern=int(R()*4);
   add(x,y,w*.5f,h*.5f,.75f,c,Panel,N()*.02f);
   if(pattern==0)for(int a=0;a<3;a++)for(int b=0;b<3;b++)add(x+(a-1)*w/3,y+(b-1)*h/3,w*.15f,h*.15f,.7f,(c+a+b)%7,Rectangle);
   else if(pattern==1){add(x,y,w*.32f,h*.32f,1.f,(c+2)%7,Rectangle,.785398f);add(x,y,w*.15f,h*.15f,.6f,(c+4)%7,Rectangle);}
   else if(pattern==2)for(int k=0;k<3;k++)add(x+(k-1)*w*.25f,y,w*.26f,h*.43f,.9f,(c+k+1)%7,Triangle,(k%2)*3.14159f);
   else for(int k=0;k<3;k++)add(x,y,w*(.4f-k*.1f),h*(.4f-k*.1f),.45f,(c+k+1)%7,Rectangle);
   for(int s=0;s<8;s++) {
    float xx=x-w*.5f+(s+.2f)*w/8,yy=y-h*.5f+(s+.2f)*h/8;
    mark(xx,y-h*.5f,xx+w*.055f,y-h*.5f,.0009f,.8f,c);d.back().c={.2f,.18f,.16f};
    mark(x-w*.5f,yy,x-w*.5f,yy+h*.055f,.0009f,.8f,c);d.back().c={.2f,.18f,.16f};
   }
  }
  scatter((int)(35*p.splatter),.005f);
  return d;
 }
 if(p.style==16) {
  float rx=fminf(asp*.43f,.55f),ry=rx*(.39f+R()*.1f),iris=ry*.94f,tilt=N()*.25f;
  int base=int(R()*7);
  add(0,0,rx,ry,2.f,base,EyeWhite);d.back().c={.98f,.94f,.86f};
  add(0,0,iris*1.15f,iris*1.15f,.55f,base,Wash);
  add(0,0,iris,iris,.65f,(base+1)%7,Backrun);
  for(int i=0;i<100;i++) {
   float a=i*6.2831853f/100,inner=iris*(.23f+R()*.2f),outer=iris*(.85f+R()*.22f);
   mark(cosf(a)*inner,sinf(a)*inner,cosf(a+.05f*sinf(i))*outer,sinf(a+.05f*sinf(i))*outer,.003f+R()*.004f,.16f+R()*.24f,(base+i%3)%7);
  }
  add(0,0,iris*1.1f,iris*1.1f,.28f,base,Ring);d.back().c={.08f,.12f,.17f};
  add(0,0,iris*.36f,iris*.36f,2.4f,base,Drop);d.back().c={.01f,.015f,.025f};
  for(int side=-1;side<=1;side+=2) {
   float lastX=-rx,lastY=0;
   for(int i=1;i<=90;i++) {
    float u=-1+2*i/90.f,x=u*rx,y=side*ry*(1-u*u);
    mark(lastX,lastY,x,y,side<0?.0035f:.0025f,.4f,base);d.back().c={.12f,.09f,.14f};
    if(side<0&&i%7==0)mark(x,y,x+u*.013f,y-.018f-R()*.018f,.0015f,.9f,base);
    lastX=x;lastY=y;
   }
  }
  add(-iris*.28f,-iris*.33f,iris*.12f,iris*.10f,2.f,base,Star);d.back().c={1.f,.99f,.95f};
  add(iris*.14f,iris*.17f,iris*.045f,iris*.045f,1.2f,base,Star);d.back().c={.98f,.98f,.94f};
  transform(tilt,N()*asp*.05f,N()*.05f);
  scatter((int)(50*p.splatter),.007f);
  return d;
 }
 if(p.style==14) {
  int base=int(R()*7);float rotation=R()*3.14f;
  add(0,0,asp*2.5f,2.5f,1.5f,base,Wash);d.back().c={.12f,.10f,.26f};
  for(int i=0;i<60;i++) {
   float t=(R()-.5f)*1.3f,u=t*asp,v=.13f*sinf(t*6)+N()*.13f;
   float x=u*cosf(rotation)-v*sinf(rotation),y=u*sinf(rotation)+v*cosf(rotation);
   float size=.055f+R()*.19f;int color=(base+i%4)%7;
   add(x,y,size*1.5f,size,.18f+R()*.3f,color,GlowWash,R()*6.28f);
  }
  // Drifting ink provides dark dust lanes through the colored clouds.
  for(int i=0;i<15;i++) {
   float t=(i/14.f-.5f),u=t*asp,v=.08f*sinf(t*8);
   add(u*cosf(rotation)-v*sinf(rotation),u*sinf(rotation)+v*cosf(rotation),.1f,.025f+R()*.04f,.16f,base,Wash,rotation);
   d.back().c={.13f,.16f,.30f};
  }
  // Reserve-like stars are composited as pale pigment by the star brush.
  for(int i=0;i<210;i++) {
   float x=(R()-.5f)*asp,y=R()-.5f,s=.0007f+powf(R(),5)*.0045f;
   add(x,y,s,s,1.f,base,Circle);d.back().c={1.f,.96f,.80f};d.back().kind=Star;
   if(i%30==0){mark(x-s*3,y,x+s*3,y,s*.18f,.75f,base);d.back().kind=Star;mark(x,y-s*3,x,y+s*3,s*.18f,.75f,base);d.back().kind=Star;}
  }
  return d;
 }
 if(p.style==13) {
  float tilt=(R()-.5f)*1.6f,flatten=.4f+R()*.3f;
  int planets=4+int(R()*5),base=int(R()*7);
  float scale=fminf(.43f,asp*.39f),cx=N()*asp*.04f,cy=N()*.03f;
  for(int i=0;i<planets;i++) {
   float radius=scale*(.25f+.75f*(i+1)/planets),lastX=0,lastY=0;
   for(int j=0;j<=150;j++) {
    float t=j*6.2831853f/150,u=radius*cosf(t),v=radius*flatten*sinf(t);
    float x=cx+u*cosf(tilt)-v*sinf(tilt),y=cy+u*sinf(tilt)+v*cosf(tilt);
    if(j&&R()>.045f)mark(lastX,lastY,x,y,.0009f,.35f,(base+i)%7);
    lastX=x;lastY=y;
   }
   float a=R()*6.28f,u=radius*cosf(a),v=radius*flatten*sinf(a);
   float x=cx+u*cosf(tilt)-v*sinf(tilt),y=cy+u*sinf(tilt)+v*cosf(tilt),size=.014f+R()*.03f;
   add(x,y,size,size,1.3f,(base+i)%7,Circle);
   add(x+size*.25f,y+size*.15f,size*.7f,size*.8f,.35f,(base+i)%7,Circle);d.back().c={.15f,.2f,.3f};
   if(i%3==0)add(x,y,size*1.85f,size*.55f,.7f,(base+i+2)%7,Ring,tilt+.2f);
   for(int m=0;m<int(R()*3);m++){float a=R()*6.28f;add(x+cosf(a)*size*2.5f,y+sinf(a)*size*2.5f,.003f,.003f,.9f,(base+i+3)%7,Circle);}
  }
  for(int i=0;i<8;i++){float s=.07f-i*.007f;add(cx,cy,s,s,.1f+ i*.035f,4,Wash);d.back().c={1.f,.78f,.12f};}
  add(cx,cy,.017f,.017f,.9f,4,Circle);d.back().kind=Star;d.back().c={1.f,.89f,.5f};
  scatter((int)(100*p.splatter),.003f);
  return d;
 }
 bool mobius=p.style==12||(p.style==10&&R()<.45f);
 if(mobius) {
  float radius=fminf(.31f,asp*.29f),width=radius*(.28f+R()*.22f),tilt=(R()-.5f)*1.3f;
  int base=int(R()*7);
  for(int lane=0;lane<17;lane++) {
   float s=(lane/16.f-.5f)*2*width,lastX=0,lastY=0;
   for(int j=0;j<=180;j++) {
    float t=j*6.2831853f/180;
    float u=(radius+s*cosf(t*.5f))*cosf(t),v=(radius+s*cosf(t*.5f))*sinf(t)*.58f+s*sinf(t*.5f)*.95f;
    float x=u*cosf(tilt)-v*sinf(tilt),y=u*sinf(tilt)+v*cosf(tilt);
    if(j)mark(lastX,lastY,x,y,width*.1f,lane==0||lane==16?.65f:.15f,(base+int(t*3/6.2831853f)+lane/7)%7);
    lastX=x;lastY=y;
   }
  }
  transform(N()*.2f,N()*asp*.1f,N()*.1f);
  scatter((int)(90*p.splatter),.009f);
  return d;
 }
 if(p.style==11) {
  float size=fminf(.43f+R()*.035f,asp*.75f),x=N()*asp*.12f,y=N()*.015f;
  float angle=N()*.4f,phase=R()*20,bodyWidth=size*(.92f+R()*.16f);
  if(R()<.2f){angle=(R()<.5f?-1:1)*(1.1f+R()*.35f);size=fminf(size,asp*.43f);bodyWidth=size*(.92f+R()*.16f);}
  int color=int(R()*7),kind=R()<.5f?FigureFemale:FigureMale;
  auto study=makeFigures(p.seed);
  const Point* outline=kind==FigureFemale?study.female:study.male;
  int outlineCount=kind==FigureFemale?study.femaleCount:study.maleCount;
  float minX=100,minY=100,maxX=-100,maxY=-100;
  for(int i=0;i<outlineCount;i++) {
   float u=outline[i].x*bodyWidth,v=outline[i].y*size;
   float xx=u*cosf(angle)-v*sinf(angle),yy=u*sinf(angle)+v*cosf(angle);
   minX=std::min(minX,xx);maxX=std::max(maxX,xx);minY=std::min(minY,yy);maxY=std::max(maxY,yy);
  }
  float fit=std::min(1.f,std::min(asp*.88f/(maxX-minX),.88f/(maxY-minY)));
  size*=fit;bodyWidth*=fit;
  x=std::clamp(x,-asp*.46f-minX*fit,asp*.46f-maxX*fit);
  y=std::clamp(y,-.46f-minY*fit,.46f-maxY*fit);
  for(int j=0;j<9;j++)add(x+N()*.15f,y+N()*.28f,.09f+R()*.13f,.08f+R()*.16f,.1f,color,Wash,R()*6.28f);
  add(x,y,bodyWidth,size,1.65f+R()*.5f,color,kind,angle);d.back().phase=phase;
  V figureColor=palettes[p.palette][color];
  figureColor={.15f+.85f*figureColor.r,.15f+.85f*figureColor.g,.15f+.85f*figureColor.b};d.back().c=figureColor;
  add(x+N()*.003f,y+N()*.004f,bodyWidth,size,.22f,color,kind,angle);d.back().phase=phase;d.back().c=figureColor;
  for(int j=0;j<5;j++)add(x+N()*.09f,y+size*.92f+N()*.01f,.06f,.01f,.13f,color,Wash);
  scatter((int)(55*p.splatter),.009f);
  return d;
 }
 if(p.style==8) {
  // An original textile-inspired composition: woven bands, diamonds, chevrons,
  // and resist-like paper gaps, rather than a reproduction of a cultural symbol.
  float tilt=N()*.15f; int bands=4+int(R()*5),rows=4+int(R()*6),motif=int(R()*3);
  for(int band=0;band<bands;band++) {
   float x=(band-(bands-1)*.5f)*asp*.85f/bands;int color=(band*2+int(R()*3))%7;
   float halfwidth=asp*(.28f+R()*.14f)/bands;
   add(x,N()*.03f,halfwidth,.37f+R()*.1f,.75f+R()*.55f,color,Panel,tilt);
   for(int row=0;row<rows;row++) {
    float y=(row-(rows-1)*.5f)*.8f/rows+N()*.012f,dx=halfwidth*.8f,dy=.25f/rows;
    int accent=(color+2+row%3)%7;
    if((row+band+motif)%3==0) {
     add(x,y,dx*1.1f,dy,1.1f,accent,Triangle,(row%2)*3.14159f);
    } else if((row+band+motif)%3==1) {
     add(x,y,dx,dy,1.1f,accent,Ring,R()*6.28f);
    } else {
    mark(x,y-dy,x+dx,y,.0035f,.85f,accent);
    mark(x+dx,y,x,y+dy,.0035f,.85f,accent);
    mark(x,y+dy,x-dx,y,.0035f,.85f,accent);
    mark(x-dx,y,x,y-dy,.0035f,.85f,accent);
    }
    add(x,y,.008f,.012f,.9f,accent,Circle);
    for(int h=0;h<3;h++) {
     float yy=y-.024f+h*.024f;
     mark(x+dx*.55f,yy,x+dx*.9f,yy-.01f,.0015f,.65f,(accent+1)%7);
    }
   }
  }
  for(int row=0;row<2;row++)for(int i=0;i<35;i++) {
   float x=(i-17)*asp*.025f,y=row? .46f:-.46f;
   add(x,y,.0028f,.004f,.8f,(i+row)%7,Drop);
  }
  transform((R()-.5f)*1.3f,N()*asp*.05f,N()*.04f);
  scatter((int)(65*p.splatter),.008f);
  return d;
 }
 if(p.style==9) {
  float radius=fminf(.23f+R()*.11f,asp*.34f),rotation=R()*6.2831853f;
  int dark=int(R()*7),light=(dark+3)%7;
  int petals=12+int(R()*20),beads=36+int(R()*65);
  for(int i=0;i<petals;i++) {
   float a=i*6.2831853f/petals,rr=radius*(1.12f+R()*.25f);
   add(cosf(a)*rr,sinf(a)*rr,.035f+R()*.025f,.025f+R()*.03f,.16f,i%2?dark:light,Wash,a);
  }
  add(0,0,radius,radius,2.3f,dark,YinDark,rotation);
  // Concentrated indigo-like shading makes the two lobes read clearly in any palette.
  d.back().c.r*=.25f;d.back().c.g*=.3f;d.back().c.b*=.4f;
  add(0,0,radius,radius,.95f,light,YinLight,rotation);
  for(int i=0;i<beads;i++) {
   if(R()<.12f)continue;
   float a=i*6.2831853f/beads,rr=radius*(1.32f+N()*.06f);
   add(cosf(a)*rr,sinf(a)*rr,.0025f,.003f,.7f,i%3?dark:light,Drop);
   if(i%6==0)mark(cosf(a)*rr*1.04f,sinf(a)*rr*1.04f,cosf(a)*rr*1.15f,sinf(a)*rr*1.15f,.0018f,.65f,light);
  }
  transform(N()*.5f,N()*asp*.11f,N()*.09f);
  scatter((int)(55*p.splatter),.009f);
  return d;
 }
 if(p.style==10) {
  float sx=fminf(asp*.38f,.52f)*(.75f+R()*.3f),sy=.19f+R()*.18f,rotation=N()*.9f;
  float wobble=R()*.16f,phase=R()*6.28f;
  int base=int(R()*7),ribbons=2+int(R()*4),ornament=4+int(R()*6);
  for(int ribbon=0;ribbon<ribbons;ribbon++) {
   float offset=(ribbon-(ribbons-1)*.5f)*.014f,lastX=0,lastY=0;
   for(int j=0;j<=220;j++) {
    float t=j*6.2831853f/220;
    float u=sx*cosf(t)*(1+wobble*sinf(t*3+phase)),v=sy*sinf(2*t)*(.74f+.12f*cosf(t+phase));
    float x=u*cosf(rotation)-v*sinf(rotation);
    float y=u*sinf(rotation)+v*cosf(rotation)+offset;
    int color=(base+int(t/6.2831853f*6))%7;
    float width=.009f+.011f*(.5f+.5f*sinf(t*3+ribbon));
    if(j)mark(lastX,lastY,x,y,width,ribbon==1?.48f:.2f,color);
    if(ribbon==1&&j%ornament==0&&R()>.15f) {
     float norm=sqrtf(sx*sx*sinf(t)*sinf(t)+4*sy*sy*.74f*.74f*cosf(2*t)*cosf(2*t));
     float nx=-2*sy*.74f*cosf(2*t)/fmaxf(norm,.001f),ny=-sx*sinf(t)/fmaxf(norm,.001f);
     float reach=.027f+(j%12?0:.02f);
     mark(x+nx*.023f,y+ny*.023f,x+nx*(.023f+reach),y+ny*(.023f+reach),.002f,.7f,(color+2)%7);
     add(x-nx*.033f,y-ny*.033f,.0035f,.0035f,.75f,(color+3)%7,Drop);
    }
    lastX=x;lastY=y;
   }
  }
  for(int i=0;i<8;i++) {
   float a=R()*6.28f;
   add(cosf(a)*sx,sinf(2*a)*sy*.74f,.05f,.04f,.16f,(base+i)%7,Wash);
  }
  transform(N()*.2f,N()*asp*.08f,N()*.08f);
  scatter((int)(100*p.splatter),.012f);
  return d;
 }
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
 if(!output||p.width<1||p.height<1||p.width>8192||p.height>8192||p.palette<0||p.palette>10||p.style<0||p.style>18){snprintf(error,errorLength,"Invalid render settings");return -1;}
 auto d=compose(p);auto figures=makeFigures(p.seed);size_t bytes=(size_t)p.width*p.height*4;
 int count=0;cudaError_t e=cudaGetDeviceCount(&count);
 if(e==cudaSuccess&&count>0){
  unsigned char* pixels=nullptr;Dab* drops=nullptr;FigureContours* deviceFigures=nullptr;
  e=cudaMalloc(&pixels,bytes);
  if(e==cudaSuccess)e=cudaMalloc(&drops,d.size()*sizeof(Dab));
  if(e==cudaSuccess)e=cudaMalloc(&deviceFigures,sizeof(FigureContours));
  if(e==cudaSuccess)e=cudaMemcpy(deviceFigures,&figures,sizeof(FigureContours),cudaMemcpyHostToDevice);
  if(e==cudaSuccess)e=cudaMemcpy(drops,d.data(),d.size()*sizeof(Dab),cudaMemcpyHostToDevice);
  if(e==cudaSuccess){renderKernel<<<dim3((p.width+15)/16,(p.height+15)/16),dim3(16,16)>>>(pixels,p,drops,(int)d.size(),deviceFigures);e=cudaGetLastError();}
  if(e==cudaSuccess)e=cudaMemcpy(output,pixels,bytes,cudaMemcpyDeviceToHost);
  cudaFree(pixels);cudaFree(drops);cudaFree(deviceFigures);
  if(e==cudaSuccess)return 1;
  snprintf(error,errorLength,"CUDA: %s; used CPU fallback",cudaGetErrorString(e));
 }
 #pragma omp parallel for
 for(int y=0;y<p.height;y++)for(int x=0;x<p.width;x++)pixel(x,y,output,p,d.data(),(int)d.size(),&figures);
 return 0;
}
