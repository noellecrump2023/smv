#ifndef SVZIP_H_DEFINED
#define SVZIP_H_DEFINED
#include "lint.h"
//***********************
//************* #definess
//***********************
#ifdef INMAIN
#define EXTERN
#else
#define EXTERN extern
#endif
#include "csphere.h"
#include "string_util.h"
#include "file_util.h"

#include "histogram.h"
#include "threader.h"
#include "smv_endian.h"

#ifdef pp_PART
#define rgb_white 12
#define rgb_yellow 13
#define rgb_blue 14
#define rgb_red 15
#define rgb_green 16
#define rgb_magenta 17
#define rgb_cyan 18
#define rgb_black 19
#endif

#ifndef MAX
#define MAX(a,b)  ((a)>(b) ? (a) : (b))
#define MIN(a,b)  ((a)<(b) ? (a) : (b))
#endif

#ifndef CLAMP
#define CLAMP(x,lo,hi)  MIN(MAX((x),(lo)),(hi))
#endif

#ifndef GETINDEX
#define GETINDEX(xval,xmin,dx,nx) CLAMP(((xval)-(xmin))/(dx),0,(nx)-1)
#endif


#ifdef X64
#ifndef STRUCTSTAT
#define STRUCTSTAT struct __stat64
#endif
#ifndef STAT
#define STAT _stat64
#endif
#else
#ifndef STRUCTSTAT
#define STRUCTSTAT struct stat
#endif
#ifndef STAT
#define STAT stat
#endif
#endif

#ifdef pp_SMOKE3D_FORT
#ifndef C_FILE
#define C_FILE 0
#endif
#ifndef FORTRAN_FILE
#define FORTRAN_FILE 1
#endif

#define FORTSMOKEREAD(var,size, count,STREAM,option) \
                           if(option==1){FSEEK(STREAM,4,SEEK_CUR);}\
                           fread(var,size,count,STREAM);\
                           if(option==1){FSEEK(STREAM,4,SEEK_CUR);}

#define FORTSMOKEREADBR(var,size, count,STREAM,option) \
                           if(option==1){FSEEK(STREAM,4,SEEK_CUR);}\
                           returncode=fread(var,size,count,STREAM);\
                           if(returncode!=count||returncode==0)break;\
                           if(option==1){FSEEK(STREAM,4,SEEK_CUR);}
#else
#define FORTSMOKEREAD(var,size, count,STREAM,option) \
                           fread(var,size,count,STREAM)

#define FORTSMOKEREADBR(var,size, count,STREAM,option) \
                           returncode=fread(var,size,count,STREAM);\
                           if(returncode!=count||returncode==0){
                             break;\
                           }
#endif


//***********************
//************* structures
//***********************


/* --------------------------  volrenderdata ------------------------------------ */

typedef struct {
  struct _meshdata *rendermesh;
  struct _slicedata *smoke, *fire;
} volrenderdata;

/* --------------------------  mesh ------------------------------------ */

typedef struct _meshdata {
  int ibar, jbar, kbar;
  float *xplt, *yplt, *zplt;
  float *xpltcell, *ypltcell, *zpltcell;
  float xbar0, xbar, ybar0, ybar, zbar0, zbar;
  float dx, dy, dz;
  float dxx, dyy, dzz;
  volrenderdata volrenderinfo;
} meshdata;

/* --------------------------  patch ------------------------------------ */

typedef struct {
  char *file,*filebase;
  int unit_start;
  char summary[1024];
  int compressed;
  int filesize;
  int inuse,inuse_getbounds;
  int seq_id, autozip;
  int doit, done;
  int *pi1, *pi2, *pj1, *pj2, *pk1, *pk2, *patchdir, *patchsize;
  int npatches;
  int setvalmin, setvalmax;
  float valmin, valmax;
  int version;
  histogramdata *histogram;
  flowlabels label;
  int dup;
} patch;

/* --------------------------  slice ------------------------------------ */

typedef struct _slicedata {
  char *file,*filebase,*boundfile;
  int isvolslice,voltype;
  int unit_start;
  int blocknumber;
  char summary[1024];
  char volsummary[1024];
  int compressed,vol_compressed;
  int inuse,involuse,inuse_getbounds;
  int filesize;
  int seq_id,autozip;
  int doit, done, count;
  int setvalmin, setvalmax;
  float valmin, valmax;
  int setchopvalmin, setchopvalmax;
  float chopvalmin, chopvalmax;
  int version;
  histogramdata *histogram;
  flowlabels label;
  int dup;
} slicedata;

/* --------------------------  bound ------------------------------------ */

typedef struct {
  int setvalmin, setvalmax;
  float valmin, valmax;
} bounddata;

/* --------------------------  plot3d ------------------------------------ */

typedef struct {
  char *file,*filebase;
  int unit_start;
  char summary[1024];
  int compressed;
  int inuse;
  float time;
  int blocknumber;
  meshdata *plot3d_mesh;
  int filesize;
  int seq_id,autozip;
  int doit, done, count;
  bounddata bounds[5];
  int version;
  flowlabels labels[5];
  int dup;
} plot3d;

/* --------------------------  vert ------------------------------------ */

typedef struct {
  float normal[3];
} vert;

/* --------------------------  smoke3d ------------------------------------ */

typedef struct {
  char *file,*filebase;
  int unit_start;
#ifdef pp_SMOKE3D_FORT
  int file_type;
#endif
  char summary[1024];
  int compressed;
  int inuse,is_soot;
  int seq_id, autozip;
  int nx, ny, nz, filesize;
  meshdata *smokemesh;
  unsigned char *compressed_lightingbuffer;
  uLongf ncompressed_lighting_zlib;
} smoke3d;

#ifdef pp_PART

/* --------------------------  partpropdata ------------------------------------ */

typedef struct {
  int used;
  char isofilename[1024];
  float *partvals;
  flowlabels label;
  float valmin, valmax;
  histogramdata *histogram;
  int setvalmin, setvalmax;
} partpropdata;

/* --------------------------  partclass ------------------------------------ */

typedef struct {
  char *name;
  int ntypes;
  flowlabels *labels;
} partclassdata;

/* --------------------------  part5data ------------------------------------ */

typedef struct {
  int npoints,n_rtypes, n_itypes;
  int *tags,*sort_tags;
  float *rvals;
  unsigned char *irvals;
  unsigned char **cvals;
} part5data;

/* --------------------------  part ------------------------------------ */

typedef struct {
  char *file,*filebase;
  char summary[1024], summary2[1024];
  int unit_start;
  char **summaries;
  int nsummaries;
  int compressed,compressed2;
  int inuse,inuse_part2iso;
  int filesize;
  int seq_id, autozip;
  int setvalmin, setvalmax;
  float valmin, valmax;
  flowlabels *label;
  meshdata *partmesh;

  int nclasses;
  partclassdata **classptr;
  part5data *data5;
} part;
#endif

#define PDFMAX 100000
typedef struct {
  int ncount;
  int buckets[PDFMAX];
  float pdfmin,pdfmax;
} pdfdata;

#define BOUND(x,xmin,xmax) (((x)<(xmin))?(xmin):((x)>(xmax))?(xmax):(x))
#define GET_INTERVAL(xyz,xyz0,dxyz) (((xyz)-(xyz0))/(dxyz))


//***********************
//************* headers
//***********************

void InitVolRender(void);
void print_summary(void);
void *compress_all(void *arg);
void mt_compress_all(void);
void RandABsdir(float xyz[3], int dir);
void rand_cone_dir(float xyz[3], float dir[3], float mincosangle);
void rand_sphere_dir(float xyz[3]);
float Rand1D(float xmin, float xmax);
void Rand2D(float xy[2], float xmin, float xmax, float ymin, float ymax);
void Rand3D(float xyz[3], float xmin, float xmax, float ymin, float ymax, float zmin, float zmax);
void GetStartupSlice(int seq_id);
void GetStartupSmoke(int seq_id);
void GetStartupBoundary(int seq_id);
unsigned int UnCompressRLE(unsigned char *buffer_in, int nchars_in, unsigned char *buffer_out);
int ReadSMV(char *file);
slicedata *GetSlice(char *string);
void *CompressSlices(void *arg);
void *CompressVolSlices(void *arg);
int plot3ddup(plot3d *plot3dj, int iplot3d);
int SliceDup(slicedata *slicej, int islice);
void *compress_plot3ds(void *arg);
void initpdf(pdfdata *pdf);
void makesvd(char *destdir, char *smvfile);
void getpdf(float *vals, int nvals, pdfdata *pdf);
void mergepdf(pdfdata *pdf1, pdfdata *pdf2, pdfdata *pdfmerge);
#ifdef pp_PART
void compress_parts(void *arg);
void *convert_parts2iso(void *arg);
part *getpart(char *string);
partpropdata *getpartprop(char *string);
int getpartprop_index(char *string);
void convert_part(part *parti, int *thread_index);
int convertable_part(part *parti);
#endif
void *compress_patches(void *arg);
patch *getpatch(char *string);
int patchdup(patch *patchj, int ipatch);
void ReadINI(char *file);
void ReadINI2(char *file2);
void Get_Boundary_Bounds(void);
#ifdef pp_PART
void Get_Part_Bounds(void);
#endif
void convert_3dsmoke(smoke3d *smoke3di, int *thread_index);
void *compress_smoke3ds(void *arg);
void Normal(unsigned short *v1, unsigned short *v2, unsigned short *v3, float *normal, float *area);
float atan3(float y, float x);
void initvolrender(void);
void GetSliceParmsC(char *file, int *ni, int *nj, int *nk);

#ifdef pp_WIN_ONEAPI
#define FORTgetpartheader1     _F(GETPARTHEADER1)
#define FORTgetpartheader2     _F(GETPARTHEADER2)
#define FORTgetpartdataframe   _F(GETPARTDATAFRAME)
#define FORTclosefortranfile   _F(CLOSEFORTRANFILE)
#define FORTgetboundaryheader1 _F(GETBOUNDARYHEADER1)
#define FORTgetboundaryheader2 _F(GETBOUNDARYHEADER2)
#define FORTopenboundary       _F(OPENBOUNDARY)
#define FORTgetpatchdata       _F(GETPATCHDATA)
#define FORTopenslice          _F(OPENSLICE)
#define FORTopenpart           _F(OPENPART)
#define FORTgetsliceframe      _F(GETSLICEFRAME)
#define FORTgetplot3dq         _F(GETPLOT3DQ)
#else
#define FORTgetpartheader1     _F(getpartheader1)
#define FORTgetpartheader2     _F(getpartheader2)
#define FORTgetpartdataframe   _F(getpartdataframe)
#define FORTclosefortranfile   _F(closefortranfile)
#define FORTgetboundaryheader1 _F(getboundaryheader1)
#define FORTgetboundaryheader2 _F(getboundaryheader2)
#define FORTopenboundary       _F(openboundary)
#define FORTgetpatchdata       _F(getpatchdata)
#define FORTopenslice          _F(openslice)
#define FORTopenpart           _F(openpart)
#define FORTgetsliceframe      _F(getsliceframe)
#define FORTgetplot3dq         _F(getplot3dq)
#endif

#ifdef WIN32
#define STDCALLF extern void _stdcall
#else
#define STDCALLF extern void
#endif

STDCALLF FORTopenpart(char *partfilename, int *unit, int *error, FILE_SIZE lenfile);
STDCALLF FORTgetpartheader1(int *unit, int *nclasses, int *fdsversion, int *size);
STDCALLF FORTgetpartheader2(int *unit, int *nclasses, int *nquantities, int *size);
STDCALLF FORTgetpartdataframe(int *unit, int *nclasses, int *nquantities, int *npoints, float *time, int *tagdata, float *pdata, int *size, int *error);

STDCALLF FORTclosefortranfile(int *lunit);

STDCALLF FORTgetpatchdata(int *lunit, int *npatch,int *pi1,int *pi2,int *pj1,int *pj2,int *pk1,int *pk2,
                         float *patch_times,float *pqq, int *ndummy, int *file_size, int *error);
STDCALLF FORTopenboundary(char *boundaryfilename, int *boundaryunitnumber,
                         int *version, int *error, FILE_SIZE len);
STDCALLF FORTgetboundaryheader1(char *boundaryfilename, int *boundaryunitnumber,
                               int *npatch, int *error, FILE_SIZE lenfile);
STDCALLF FORTgetboundaryheader2(int *boundaryunitnumber, int *version, int *npatches,
                               int *pi1, int *pi2, int *pj1, int *pj2, int *pk1, int *pk2, int *patchdir);

STDCALLF FORTgetsliceframe(int *lu11,
                          int *is1,int *is2,int *js1,int *js2,int *ks1,int *ks2,
                          float *time,float *qframe,int *slicetest, int *error);
STDCALLF FORTopenslice(char *slicefilename, int *unit,
                      int *is1, int *is2, int *js1, int *js2, int *ks1, int *ks2,
                      int *error, FILE_SIZE lenfile);

STDCALLF FORTgetplot3dq(char *qfilename, int *nx, int *ny, int *nz, float *qq, int *error, int *isotest, FILE_SIZE filelen);




//***********************
//************* variables
//***********************

EXTERN int nvolrenderinfo;
EXTERN int GLOBdoit_smoke3d, GLOBdoit_boundary, GLOBdoit_slice, GLOBdoit_plot3d, GLOBdoit_volslice;
#ifdef pp_PART2
EXTERN int GLOBdoit_particle;
#endif

EXTERN int GLOBdoit_lighting;
EXTERN FILE *SMZLOG_STREAM;

EXTERN int GLOBfirst_initsphere,GLOBfirst_slice,GLOBfirst_patch,GLOBfirst_plot3d,GLOBfirst_part2iso,GLOBfirst_part2iso_smvopen;
EXTERN int GLOBframeskip;
EXTERN int GLOBno_chop;

EXTERN patch *patchinfo;
EXTERN meshdata *meshinfo;
EXTERN smoke3d *smoke3dinfo;
EXTERN slicedata *sliceinfo;
EXTERN plot3d *plot3dinfo;
EXTERN part *partinfo;
EXTERN partclassdata *partclassinfo;
EXTERN partpropdata *part5propinfo;
EXTERN threaddata *threadinfo;
EXTERN spherepoints sphereinfo;

EXTERN int npatchinfo, nsliceinfo, nplot3dinfo, npartinfo;
EXTERN int npartclassinfo;
EXTERN int nsmoke3dinfo;
#ifdef pp_PART
EXTERN int maxpart5propinfo, npart5propinfo;
#endif


EXTERN int nmeshes;
EXTERN int GLOBoverwrite_slice;
EXTERN int GLOBoverwrite_volslice;
EXTERN int GLOBoverwrite_plot3d;
#ifdef pp_PART
EXTERN int GLOBoverwrite_part;
#endif
EXTERN int GLOBoverwrite_b,GLOBoverwrite_s;
EXTERN int GLOBcleanfiles;
EXTERN char *GLOBdestdir,*GLOBsourcedir;
EXTERN char GLOBpp[2],GLOBx[2];
EXTERN int GLOBsmoke3dzipstep, GLOBboundzipstep, GLOBslicezipstep;
EXTERN int GLOBfilesremoved;
EXTERN int GLOBsyst;
EXTERN char *GLOBendianfile;
EXTERN int GLOBautozip, GLOBmake_demo;
EXTERN int GLOBget_bounds, GLOBget_slice_bounds, GLOBget_plot3d_bounds, GLOBget_boundary_bounds;
#ifdef pp_PART
EXTERN int GLOBget_part_bounds;
EXTERN int GLOBpartfile2iso;
#endif
EXTERN char GLOBsmvisofile[1024];

#endif
