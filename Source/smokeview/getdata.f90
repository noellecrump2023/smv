!  WRITE(LU_GEOM) ONE
!  WRITE(LU_GEOM) VERSION
!  WRITE(LU_GEOM) STIME  ! first time step
!  WRITE(LU_GEOM) N_VERT_S, NFACE_S, NVERT_D, N_FACE_D
!  IF (N_VERT_S>0)  WRITE(LU_GEOM) (Xvert_S(I),Yvert_S(I),Zvert_S(I),I=1,N_VERT_S)
!  IF (N_VERT_D>0)  WRITE(LU_GEOM) (Xvert_D(I),Yvert_D(I),Zvert_D(I),I=1,N_VERT_D)
!  IF (N_FACE_S>0)  WRITE(LU_GEOM) (FACE1_S(I),FACE2_S(I),FACE3_S(I),I=1,N_FACE_S)
!  IF (N_FACE_D>0)  WRITE(LU_GEOM) (FACE1_D(I),FACE2_D(I),FACE3_D(I),I=1,N_FACE_D)
!  IF (N_FACE_S>0)  WRITE(LU_GEOM) (SURF_S(I),I=1,N_FACE_S)
!  IF (N_FACE_D>0)  WRITE(LU_GEOM) (SURF_D(I),I=1,N_FACE_D)


#ifdef __INTEL_COMPILER
#define pp_FSEEK
#endif
#ifdef pp_GCC
#define pp_FSEEK
#endif

!  ------------------ module cio ------------------------

module cio
#ifdef __INTEL_COMPILER
use ifport, only: seek_set, seek_cur
#else
integer, parameter :: seek_set=0, seek_cur=1
#endif
public ffseek, seek_set, seek_cur

contains

!  ------------------ ffseek ------------------------

subroutine ffseek(unit,sizes,nsizes,mode,error)
#ifdef __INTEL_COMPILER
use ifport, only: fseek
#endif
implicit none
integer, intent(in) :: unit, mode, nsizes
integer, intent(in), dimension(nsizes) :: sizes
integer, intent(out) :: error

integer :: i, size
#ifndef pp_FSEEK
character(len=1), dimension(:) :: cbuffer
#endif

#ifdef pp_FSEEK
size = 0
do i = 1, nsizes
  size = size + 4 + sizes(i) + 4
end do
#endif

#ifdef __INTEL_COMPILER
error = fseek(unit,size,mode)
#endif

#ifdef pp_GCC
call fseek(unit,size,mode,error)
#endif

! not Intel compiler, not GCC compiler so read in data to advance file pointer

#ifndef pp_FSEEK
size = sizes(1)
do i = 2, nsizes
  size = max(size,sizes(i))
end do
allocate(cbuffer(size))
if(mode==seek_set)rewind(unit)
do i = 1, nsizes
  read(unit)cbuffer(1:sizes(i))
end do
deallocate(cbuffer)
#endif

end subroutine ffseek
end module cio

!  ------------------ getgeomdatasize ------------------------

subroutine getgeomdatasize(filename,ntimes,nvars,error)
implicit none
character(len=*), intent(in) :: filename
integer, intent(out) :: ntimes, nvars, error

integer :: lu20, finish
logical :: exists
real :: time, dummy
integer :: i, one, version
integer :: nvert_s, nvert_d, nface_s, nface_d

inquire(file=trim(filename),exist=exists)
if(exists)then
  open(newunit=lu20,file=trim(filename),form="unformatted",action="read")
 else
  write(6,*)' The boundary element file name, ',trim(filename),' does not exist'
  error=1
  return
endif

error = 0
read(lu20)one
read(lu20)version
ntimes=0
nvars=0
do
  read(lu20,iostat=finish)time
  if(finish.eq.0)read(lu20,iostat=finish)nvert_s,nface_s,nvert_d,nface_d
  if(finish.eq.0.and.nvert_s>0)read(lu20,iostat=finish)(dummy,i=1,nvert_s)
  if(finish.eq.0.and.nvert_d>0)read(lu20,iostat=finish)(dummy,i=1,nvert_d)
  if(finish.eq.0.and.nface_s>0)read(lu20,iostat=finish)(dummy,i=1,nface_s)
  if(finish.eq.0.and.nface_d>0)read(lu20,iostat=finish)(dummy,i=1,nface_d)
  if(finish.ne.0)then
    close(lu20)
    return
  endif
  nvars = nvars + nvert_s + nvert_d + nface_s + nface_d
  ntimes = ntimes + 1
end do
close(lu20)

end subroutine getgeomdatasize

!   FORTelev2geom(output_elev_file, xgrid, ibar, yrid, jbar, vals, ibar*jbar, strlen(output_elev_file));

!  ------------------ elev2geom ------------------------

subroutine elev2geom(output_elev_file, xgrid, ibar, ygrid, jbar, vals, nvals)
implicit none
character(len=*), intent(in) :: output_elev_file
integer, intent(in) :: ibar, jbar, nvals
real, intent(in), dimension(:) :: xgrid(ibar), ygrid(jbar), vals(nvals)

integer :: lu_geom
integer :: i, j
integer :: one=1, version=1, n_floats=0, n_ints=0, first_frame_static=1
integer :: n_vert, n_face, n_vol
integer :: ivert, iface
real :: stime=0.0
real, dimension(:),allocatable :: xvert, yvert
integer, dimension(:),allocatable :: face
real, dimension(:),allocatable :: xtext, ytext

n_vert = ibar*jbar
n_face = 2*(ibar-1)*(jbar-1)
n_vol = 0

allocate(xvert(n_vert))
allocate(yvert(n_vert))
allocate(face(3*n_face))
allocate(xtext(3*n_face))
allocate(ytext(3*n_face))

open(newunit=lu_geom,file=trim(output_elev_file),form="unformatted",action="write")

ivert=1
do i = 1, ibar
   do j = 1, jbar
      xvert(ivert) = xgrid(i)
      yvert(ivert) = ygrid(j)
      xtext(ivert) = real(i-1)/real(ibar-1)
      ytext(ivert) = real(j-1)/real(jbar-1)
      ivert = ivert + 1
   end do
end do

!        j*ibar + 1,     j*ibar+ i,     j*ibar+ i+1,...    j*ibar+ibar
!    (j-1)*ibar + 1, (j-1)*ibar+ i, (j-1)*ibar+ i+1,... (j-1)ibar+ibar

iface = 1
do j = 1, jbar-1
   do i = 1, ibar-1
     face(iface)   = (j-1)*ibar+i
     face(iface+1) = (j-1)*ibar+i+1
     face(iface+2) = j*ibar+i+1
     iface = iface + 3

     face(iface)   = (j-1)*ibar+i
     face(iface+1) = j*ibar+i+1
     face(iface+2) = j*ibar+i
     iface = iface + 3
   end do
end do

write(lu_geom) one
write(lu_geom) version
write(lu_geom) n_floats, n_ints, first_frame_static
!if (n_floats>0) write(lu_geom) (float_header(i),i=1,n_floats)
!if (n_ints>0) write(lu_geom) (int_header(i),i=1,n_ints)
! geometry frame
! stime ignored if first frame is static ( first_frame_static set to 1)

write(lu_geom) stime
write(lu_geom) n_vert, n_face, n_vol
if (n_vert>0) write(lu_geom)(xvert(i),yvert(i),vals(i),i=1,n_vert)
if (n_face>0) then
   write(lu_geom) (face(i),i=1,3*n_face)
   write(lu_geom) (1,i=1,n_face)
   write(lu_geom) (xtext(i),ytext(i),i=1,3*n_face)
endif
!if (n_vol>0) then
!   write(lu_geom) (vol1(i),vol2(i),vol3(i),vol4(i),i=1,n_vol)
!   write(lu_geom) (matl(i),i=1,n_vol)
!endif
close(lu_geom)
deallocate(xvert,yvert,face,xtext,ytext)

end subroutine elev2geom

!  ------------------ getzonesize ------------------------

subroutine getzonesize(zonefilename,nzonet,nrooms,nfires,error)
implicit none
character(len=*) :: zonefilename
integer, intent(out) :: nzonet,nrooms,nfires,error

logical :: exists
integer :: lu26, version
integer :: i
real :: dummy, dummy2
integer :: exit_all

error = 0

inquire(file=trim(zonefilename),exist=exists)
if(exists)then
  open(newunit=lu26,file=trim(zonefilename),form="unformatted",action="read")
 else
  write(6,*)' The zone file name, ',trim(zonefilename),' does not exist'
  error=1
  return
endif

nzonet = 0
read(lu26,iostat=error)version
if(error.eq.0)read(lu26,iostat=error)nrooms
if(error.eq.0)read(lu26,iostat=error)nfires
if(error.ne.0)then
  error=0
  rewind(lu26)
  return
endif
do
  exit_all=0
  read(lu26,iostat=error)dummy
  if(error.ne.0)then
    error = 0
    exit
  endif
  do i = 1, nrooms
    read(lu26,iostat=error)dummy,dummy,dummy,dummy
    if(error.eq.0)cycle
    error = 0
    exit_all=1
    exit
  end do
  if(exit_all.eq.1)exit
  do i = 1, nfires
    read(lu26,iostat=error)dummy,dummy2
    if(error.eq.0)cycle
    error = 0
    exit_all=1
    exit
  end do
  if(exit_all.eq.1)exit
  nzonet = nzonet + 1
end do
close(lu26)
end subroutine getzonesize

!  ------------------ getpatchsizes1 ------------------------

subroutine getpatchsizes1(file_unit,patchfilename,npatch,headersize,error)
use cio
implicit none

character(len=*), intent(in) :: patchfilename
integer, intent(out) :: file_unit,npatch, headersize, error

integer :: sizes(3), nsizes
logical :: exists

error=0
inquire(file=trim(patchfilename),exist=exists)
if(exists)then
  open(newunit=file_unit,file=trim(patchfilename),form="unformatted",action="read")
else
  write(6,*)' The boundary file name, ',trim(patchfilename),' does not exist'
  error=1
  return
endif

sizes(1) = 30
sizes(2) = 30
sizes(3) = 30
nsizes = 3
call ffseek(file_unit,sizes,nsizes,seek_set,error) ! skip over long, short and unit labels (each 30 characters in length)
if(error.eq.0)read(file_unit,iostat=error)npatch
headersize = 3*(4+30+4) + 4 + 4 + 4

return
end subroutine getpatchsizes1

!  ------------------ getpatchsizes2 ------------------------

subroutine getpatchsizes2(file_unit,version,npatch,npatchsize,pi1,pi2,pj1,pj2,pk1,pk2,patchdir,headersize,framesize)
implicit none

integer, intent(in) :: file_unit,version, npatch
integer, intent(out) :: npatchsize
integer, intent(out), dimension(npatch) :: pi1, pi2, pj1, pj2, pk1, pk2, patchdir
integer, intent(inout) :: headersize
integer, intent(out) :: framesize

integer :: n, i1, i2, j1, j2, k1, k2, error

error=0

npatchsize = 0
do n = 1, npatch
  if(version.eq.0)then
    read(file_unit)i1, i2, j1, j2, k1, k2
   else
    read(file_unit)i1, i2, j1, j2, k1, k2, patchdir(n)
  endif
  pi1(n)=i1
  pi2(n)=i2
  pj1(n)=j1
  pj2(n)=j2
  pk1(n)=k1
  pk2(n)=k2
  npatchsize = npatchsize + (i2+1-i1)*(j2+1-j1)*(k2+1-k1)
end do
headersize = headersize + npatch*(4+6*4+4)
if(version.eq.1)headersize = headersize + npatch*4
framesize = 8+4+8*npatch+npatchsize*4

return
end subroutine getpatchsizes2

!  ------------------ getsliceparms ------------------------

subroutine getsliceparms(slicefilename, ip1, ip2, jp1, jp2, kp1, kp2, ni, nj, nk, slice3d, error)
implicit none

character(len=*) :: slicefilename
logical :: exists

integer, intent(inout) :: ip1, ip2, jp1, jp2, kp1, kp2
integer, intent(out) :: ni, nj, nk, slice3d, error

integer :: idir, joff, koff, volslice
character(len=30) :: longlbl, shortlbl, unitlbl
integer :: iip1, iip2

integer :: lu11

if(ip1.eq.-1.or.ip2.eq.-1.or.jp1.eq.-1.or.jp2.eq.-1.or.kp1.eq.-1.or.kp2.eq.-1)then
  ip1 = 0
  ip2 = 0
  jp1 = 0
  jp2 = 0
  kp1 = 0
  kp2 = 0
  error=0

  inquire(file=trim(slicefilename),exist=exists)
  if(exists)then
    open(newunit=lu11,file=trim(slicefilename),form="unformatted",action="read")
   else
    error=1
    return
  endif
  read(lu11,iostat=error)longlbl
  read(lu11,iostat=error)shortlbl
  read(lu11,iostat=error)unitlbl

  read(lu11,iostat=error)ip1, ip2, jp1, jp2, kp1, kp2
  close(lu11)
endif

ni = ip2 + 1 - ip1
nj = jp2 + 1 - jp1
nk = kp2 + 1 - kp1
if(ip1.eq.ip2.or.jp1.eq.jp2.or.kp1.eq.kp2)then
  slice3d=0
 else
  slice3d=1
endif

call getslicefiledirection(ip1,ip2,iip1, iip2, jp1,jp2,kp1,kp2,idir,joff,koff,volslice)

return
end subroutine getsliceparms

!  ------------------ getsliceheader ------------------------

subroutine getsliceheader(slicefilename, ip1, ip2, jp1, jp2, kp1, kp2, error)
use cio
implicit none

character(len=*), intent(in) :: slicefilename
integer, intent(out) :: ip1, ip2, jp1, jp2, kp1, kp2
integer, intent(out) :: error

logical :: exists
integer :: lu11, nsizes, sizes(3)

error=0
inquire(file=trim(slicefilename),exist=exists)
if(exists)then
  open(newunit=lu11,file=trim(slicefilename),form="unformatted",action="read")
 else
  error=1
  return
endif

sizes(1) = 30
sizes(2) = 30
sizes(3) = 30
nsizes = 3

call ffseek(lu11,sizes,nsizes,seek_set,error)

read(lu11,iostat=error)ip1, ip2, jp1, jp2, kp1, kp2
close(lu11)

end subroutine getsliceheader

!  ------------------ getslicesizes ------------------------

subroutine getslicesizes(slicefilename, nslicei, nslicej, nslicek, nsteps, sliceframestep,&
   error, settmin_s, settmax_s, tmin_s, tmax_s, headersize, framesize)
use cio
implicit none

character(len=*) :: slicefilename
logical :: exists

integer, intent(out) :: nslicei, nslicej, nslicek, nsteps, error
integer, intent(in) :: settmin_s, settmax_s, sliceframestep
integer, intent(out) :: headersize, framesize
real, intent(in) :: tmin_s, tmax_s

integer :: ip1, ip2, jp1, jp2, kp1, kp2
integer :: iip1, iip2
integer :: nxsp, nysp, nzsp

integer :: lu11
real :: timeval, time_max
logical :: load
integer :: idir, joff, koff, volslice
integer :: count
integer :: sizes(3), nsizes

error=0
nsteps = 0

inquire(file=trim(slicefilename),exist=exists)
if(exists)then
  open(newunit=lu11,file=trim(slicefilename),form="unformatted",action="read")
 else
  error=1
  return
endif

sizes(1) = 30
sizes(2) = 30
sizes(3) = 30
nsizes = 3
headersize = 3*(4+30+4)

call ffseek(lu11,sizes,nsizes,seek_set,error)

read(lu11,iostat=error)ip1, ip2, jp1, jp2, kp1, kp2
headersize = headersize + 4 + 6*4 + 4
if(error.ne.0)return

nxsp = ip2 + 1 - ip1
nysp = jp2 + 1 - jp1
nzsp = kp2 + 1 - kp1

call getslicefiledirection(ip1,ip2,iip1, iip2, jp1,jp2,kp1,kp2,idir,joff,koff,volslice)
nslicei = nxsp
nslicej = nysp + joff
nslicek = nzsp + koff

framesize = 4*(1+nxsp*nysp*nzsp)+16

count=-1
time_max=-1000000.0
sizes(1) = 4*nxsp*nysp*nzsp
nsizes = 1
do
  read(lu11,iostat=error)timeval
  if(error.ne.0)exit
  if((settmin_s.ne.0.and.timeval.lt.tmin_s).or.timeval.le.time_max)then
    load=.false.
   else
    load = .true.
    time_max=timeval
  endif
  if(settmax_s.ne.0.and.timeval.gt.tmax_s)then
    close(lu11)
    return
  endif
  call ffseek(lu11,sizes,nsizes,seek_cur,error)
  count = count + 1
  if(mod(count,sliceframestep).ne.0)load = .false.
  if(error.ne.0)exit
  if(load)nsteps = nsteps + 1
end do

error = 0
close(lu11)

return

end subroutine getslicesizes

!  ------------------ openpart ------------------------

subroutine openpart(partfilename, fileunit, error)
implicit none

character(len=*) :: partfilename
logical :: exists

integer, intent(out) :: fileunit
integer, intent(out) :: error

error=0
inquire(file=partfilename,exist=exists)
if(exists)then
  open(newunit=fileunit,file=partfilename,form="unformatted",action="read")
 else
  error=1
  return
endif

return
end subroutine openpart

!  ------------------ write_bingeom------------------------

subroutine write_bingeom(filename, verts, faces, surfs, n_verts, n_faces, n_surf_id, error)
implicit none
integer :: i

character(len=*), intent(in) :: filename
integer, intent(in) :: n_verts, n_faces, n_surf_id
real, dimension(*), intent(in) :: verts
integer, dimension(*), intent(in) :: faces
integer, dimension(*), intent(in) :: surfs
integer, intent(out) :: error
integer, parameter :: double = selected_real_kind(12)


integer :: n_volus
integer, dimension(4) :: volus

integer :: unitnum, integer_one=1

error=0
n_volus =0
volus(1:4)=0

open(newunit=unitnum,file=filename,form="unformatted",action="write")

write(unitnum) integer_one
write(unitnum) n_verts, n_faces, n_surf_id, n_volus
write(unitnum) (real(verts(i),double),i=1,3*n_verts)
write(unitnum) faces(1:3*n_faces)
write(unitnum) surfs(1:n_surf_id)
write(unitnum) volus(1:4*n_volus)

close(unitnum)

return
end subroutine write_bingeom

!  ------------------ openslice ------------------------

subroutine openslice(slicefilename, unitnum, is1, is2, js1, js2, ks1, ks2, error)
implicit none

character(len=*), intent(in) :: slicefilename
logical :: exists

integer, intent(out) :: unitnum, is1, is2, js1, js2, ks1, ks2, error
character(len=30) :: longlbl, shortlbl, unitlbl

error=0
exists=.true.

inquire(file=slicefilename,exist=exists)
if(exists)then
  open(newunit=unitnum,file=slicefilename,form="unformatted",action="read")
 else
  error=1
  return
endif
read(unitnum,iostat=error)longlbl
read(unitnum,iostat=error)shortlbl
read(unitnum,iostat=error)unitlbl

read(unitnum,iostat=error)is1, is2, js1, js2, ks1, ks2

return
end subroutine openslice

!  ------------------ closefortranfile ------------------------

subroutine closefortranfile(unit)
implicit none

integer, intent(in) :: unit

close(unit)

return
end subroutine closefortranfile

!  ------------------ getboundaryheader1 ------------------------

subroutine getboundaryheader1(boundaryfilename,boundaryunitnumber,npatch,error)
implicit none

character(len=*), intent(in) :: boundaryfilename
integer, intent(out) :: boundaryunitnumber, npatch, error

character(len=30) :: patchlonglabel, patchshortlabel, patchunit

logical :: exists

error=0
inquire(file=trim(boundaryfilename),exist=exists)
if(exists)then
  open(newunit=boundaryunitnumber,file=trim(boundaryfilename),form="unformatted",action="read")
 else
  write(6,*)' The boundary file name, ',trim(boundaryfilename),' does not exist'
  error=1
  return
endif

if(error.eq.0)read(boundaryunitnumber,iostat=error)patchlonglabel
if(error.eq.0)read(boundaryunitnumber,iostat=error)patchshortlabel
if(error.eq.0)read(boundaryunitnumber,iostat=error)patchunit
if(error.eq.0)read(boundaryunitnumber,iostat=error)npatch
if(error.ne.0)close(boundaryunitnumber)

return
end subroutine getboundaryheader1

!  ------------------ getboundaryheader2 ------------------------

subroutine getboundaryheader2(boundaryunitnumber,version,npatch,pi1,pi2,pj1,pj2,pk1,pk2,patchdir)
implicit none
integer, intent(in) :: boundaryunitnumber, version, npatch
integer, intent(out), dimension(npatch) :: pi1, pi2, pj1, pj2, pk1, pk2, patchdir

integer :: n
integer :: i1, i2, j1, j2, k1, k2

do n = 1, npatch
  if(version.eq.0)then
    read(boundaryunitnumber)i1, i2, j1, j2, k1, k2
   else
    read(boundaryunitnumber)i1, i2, j1, j2, k1, k2, patchdir(n)
  endif
  pi1(n)=i1
  pi2(n)=i2
  pj1(n)=j1
  pj2(n)=j2
  pk1(n)=k1
  pk2(n)=k2
end do

return
end subroutine getboundaryheader2

!  ------------------ openboundary ------------------------

subroutine openboundary(boundaryfilename,boundaryunitnumber,version,error)
implicit none

character(len=*), intent(in) :: boundaryfilename
integer, intent(out) :: boundaryunitnumber
integer, intent(in) :: version
integer, intent(out) :: error

character(len=30) :: patchlonglabel, patchshortlabel, patchunit

logical :: exists
integer :: npatch,n
integer :: i1, i2, j1, j2, k1, k2, patchdir

inquire(file=boundaryfilename,exist=exists)
if(exists)then
  open(newunit=boundaryunitnumber,file=boundaryfilename,form="unformatted",action="read")
 else
  write(6,*)' The boundary file name, ',boundaryfilename,' does not exist'
  error=1
  return
endif

read(boundaryunitnumber,iostat=error)patchlonglabel
if(error.eq.0)read(boundaryunitnumber,iostat=error)patchshortlabel
if(error.eq.0)read(boundaryunitnumber,iostat=error)patchunit
if(error.eq.0)read(boundaryunitnumber,iostat=error)npatch

do n = 1, npatch
  if(version.eq.0)then
    if(error.eq.0)read(boundaryunitnumber,iostat=error)i1, i2, j1, j2, k1, k2
   else
    if(error.eq.0)read(boundaryunitnumber,iostat=error)i1, i2, j1, j2, k1, k2, patchdir
  endif
end do

if(error.ne.0)close(boundaryunitnumber)

return
end subroutine openboundary

!  ------------------ getpartheader1 ------------------------

subroutine getpartheader1(unit,nclasses,fdsversion,size)
implicit none

integer, intent(in) :: unit
integer, intent(out) :: nclasses,fdsversion,size

integer :: one

read(unit)one
read(unit)fdsversion

read(unit)nclasses
size=12

return

end subroutine getpartheader1

!  ------------------ getpartheader2 ------------------------

subroutine getpartheader2(unit,nclasses,nquantities,size)
implicit none

integer, intent(in) :: unit,nclasses
integer, intent(out), dimension(nclasses) :: nquantities
integer, intent(out) :: size

character(len=30) :: clabel
integer :: i, j, dummy

size=0

do i = 1, nclasses
  read(unit)nquantities(i),dummy
  size=size+4+2*nquantities(i)*(4+30+4)
  do j=1, nquantities(i)
    read(unit)clabel
    read(unit)clabel
  end do
end do

return

end subroutine getpartheader2

!  ------------------ getpartdataframe ------------------------

subroutine getpartdataframe(unit,nclasses,nquantities,npoints,time,tagdata,pdata,size,error)
implicit none

integer, intent(in) :: unit,nclasses
integer, intent(in), dimension(nclasses) :: nquantities
integer, intent(out), dimension(nclasses) :: npoints
real, intent(out), dimension(*) :: pdata
integer, intent(out), dimension(*) :: tagdata
real, intent(out) :: time
integer, intent(out) :: size,error

integer :: pstart, pend
integer :: tagstart, tagend
integer :: i, j, nparticles

size=0
pend=0
tagend=0
error=0
read(unit,iostat=error)time
size=4
if(error.ne.0)return
do i = 1, nclasses
  read(unit,iostat=error)nparticles
  if(error.ne.0)return
  npoints(i)=nparticles

  pstart=pend+1
  pend=pstart+3*nparticles-1
  read(unit,iostat=error)(pdata(j),j=pstart,pend)
  if(error.ne.0)return

  tagstart = tagend + 1
  tagend = tagstart + nparticles - 1
  read(unit,iostat=error)(tagdata(j),j=tagstart,tagend)
  if(error.ne.0)return

  if(nquantities(i).gt.0)then
    pstart = pend + 1
    pend = pstart + nparticles*nquantities(i) - 1
    read(unit,iostat=error)(pdata(j),j=pstart,pend)
    if(error.ne.0)return
  endif
  size=size+4+(4*3*nparticles)+4*nparticles+4*nparticles*nquantities(i)
end do
error=0

   end subroutine getpartdataframe

   !  ------------------ geomout ------------------------

subroutine geomout(verts, N_VERT_S, faces, N_FACE_S)
implicit none
integer, intent(in) :: N_VERT_S, N_FACE_S
real, intent(in), dimension(3*N_VERT_S) :: verts
integer, intent(in), dimension(3*N_FACE_S) :: faces;
integer :: LU_GEOM, ONE
real :: STIME
integer :: dummy, VERSION, N_VERT_D, N_FACE_D
integer :: I

ONE=1
LU_GEOM = 40
STIME = 0.0
dummy = 0
VERSION=0
N_VERT_D=0
N_FACE_D=0

OPEN(UNIT=LU_GEOM,FILE="terrain.geom",FORM='UNFORMATTED')
WRITE(LU_GEOM) ONE
WRITE(LU_GEOM) VERSION
WRITE(LU_GEOM) STIME  ! first time step
WRITE(LU_GEOM) N_VERT_S, N_FACE_S, N_VERT_D, N_FACE_D
IF (N_VERT_S>0)  WRITE(LU_GEOM) (verts(3*I-2),verts(3*I-1),verts(3*I),I=1,N_VERT_S)
IF (N_FACE_S>0)  WRITE(LU_GEOM) (faces(3*I-2),faces(3*I-1),faces(3*I),I=1,N_FACE_S)
!IF (N_FACE_S>0)  WRITE(LU_GEOM) (1,I=1,N_FACE_S)
close(LU_GEOM)
end subroutine geomout

!  ------------------ getgeomdata ------------------------

subroutine getgeomdata(filename,ntimes,nvals,times,nstatics,ndynamics,vals,file_size,error)
implicit none
character(len=*), intent(in) :: filename
integer, intent(in) :: ntimes, nvals
integer, intent(out) :: file_size, error
real, intent(out), dimension(:) :: times(ntimes), vals(nvals)
integer, intent(out), dimension(:) :: nstatics(ntimes), ndynamics(ntimes)

integer :: lu20, finish
logical :: exists
integer :: i;
integer :: one, itime, nvars
integer :: nvert_s, ntri_s, nvert_d, ntri_d
integer :: version

file_size = 0
inquire(file=trim(filename),exist=exists)
if(exists)then
  open(newunit=lu20,file=trim(filename),form="unformatted",action="read")
 else
  write(6,*)' The boundary element file name, ',trim(filename),' does not exist'
  error=1
  return
endif

error = 0
read(lu20)one
read(lu20)version
file_size = 2*(4+4+4)
nvars=0
do itime=1, ntimes
  read(lu20,iostat=finish)times(itime)
  file_size = file_size + (4+4+4)
  if(finish.eq.0)then
    read(lu20,iostat=finish)nvert_s, ntri_s, nvert_d, ntri_d
    file_size = file_size + (4+4*4+4)
    nstatics(itime)=nvert_s+ntri_s
  endif

  if(finish.eq.0)then
    if(nvert_s.gt.0)then
      read(lu20,iostat=finish)(vals(nvars+i),i=1,nvert_s)
      file_size = file_size + (4+4*nvert_s+4)
    endif
    nvars = nvars + nvert_s
  endif

  if(finish.eq.0)then
    if(ntri_s.gt.0)then
      read(lu20,iostat=finish)(vals(nvars+i),i=1,ntri_s)
      file_size = file_size + (4+4*ntri_s+4)
    endif
    nvars = nvars + ntri_s
  endif

  ndynamics(itime)=nvert_d+ntri_d
  if(finish.eq.0)then
    if(nvert_d.gt.0)then
      read(lu20,iostat=finish)(vals(nvars+i),i=1,nvert_d)
      file_size = file_size + (4+4*nvert_d+4)
    endif
    nvars = nvars + nvert_d
  endif

  if(finish.eq.0)then
    if(ntri_d.gt.0)then
      read(lu20,iostat=finish)(vals(nvars+i),i=1,ntri_d)
      file_size = file_size + (4+4*ntri_d+4)
    endif
    nvars = nvars + ntri_d
  endif

  if(finish.ne.0)then
    close(lu20)
    return
  endif
end do
close(lu20)

end subroutine getgeomdata

!  ------------------ getzonedata ------------------------

subroutine getzonedata(zonefilename,nzonet,nrooms, nfires, zonet,zoneqfire,zonepr, zoneylay,zonetl,zonetu,error)
implicit none
character(len=*) :: zonefilename
integer, intent(in) :: nrooms, nfires
integer, intent(inout) :: nzonet
real, intent(out), dimension(nrooms*nzonet) :: zonepr, zoneylay, zonetl, zonetu
real, intent(out), dimension(nfires*nzonet) :: zoneqfire
real, intent(out), dimension(nzonet) :: zonet
integer , intent(out) :: error

integer :: lu26,i,j,ii,ii2,idummy,version
real :: dummy, qdot
logical :: exists

inquire(file=trim(zonefilename),exist=exists)
if(exists)then
  open(newunit=lu26,file=trim(zonefilename),form="unformatted",action="read")
 else
  write(6,*)' The zone file name, ',trim(zonefilename),' does not exist'
  error=1
  return
endif

read(lu26)version
read(lu26)idummy
read(lu26)idummy
ii = 0
ii2 = 0
do j = 1, nzonet
  read(lu26)zonet(j)
  do i = 1, nrooms
    ii = ii + 1
    read(lu26,iostat=error)zonepr(ii),zoneylay(ii),zonetl(ii),zonetu(ii)
    if(error.ne.0)then
      error = 1
      nzonet = j - 1
      close(lu26)
      return
    endif
  end do
  do i = 1, nfires
    ii2 = ii2 + 1
    read(lu26,iostat=error)dummy,qdot
    zoneqfire(ii2) = qdot
    if(error.ne.0)then
      error=1
      nzonet=j-1
      close(lu26)
      return
    endif
  end do
end do

close(lu26)
end subroutine getzonedata

!  ------------------ skipdata ------------------------

subroutine skipdata(file_unit,skip)
use cio
implicit none

integer, intent(in) :: file_unit, skip

integer :: error, sizes(1), nsizes

sizes(1) = skip
nsizes = 1

call ffseek(file_unit,sizes,nsizes,seek_cur,error)

end subroutine skipdata

!  ------------------ getpatchdata ------------------------

subroutine getpatchdata(file_unit,npatch,pi1,pi2,pj1,pj2,pk1,pk2,patchtime,pqq,npqq,file_size,error)
implicit none

integer, intent(in) :: npatch,file_unit
integer, intent(in), dimension(*) :: pi1, pi2, pj1, pj2, pk1, pk2
real, intent(out), dimension(*) :: pqq
integer, intent(out) :: error,npqq,file_size
real, intent(out) :: patchtime

integer :: i, i1, i2, j1, j2, k1, k2, size, ibeg, iend, ii

file_size=0;
error=0
read(file_unit,iostat=error)patchtime
file_size = file_size + 4;
if(error.ne.0)then
  close(file_unit)
  return
endif
ibeg = 1
npqq=0
do i = 1, npatch
  i1 = pi1(i)
  i2 = pi2(i)
  j1 = pj1(i)
  j2 = pj2(i)
  k1 = pk1(i)
  k2 = pk2(i)
  size = (i2+1-i1)*(j2+1-j1)*(k2+1-k1)
  npqq=npqq+size
  iend = ibeg + size - 1
  read(file_unit,iostat=error)(pqq(ii),ii=ibeg,iend)
  file_size = file_size + 4*(iend+1-ibeg)
  if(error.ne.0)then
    close(file_unit)
    exit
  endif
  ibeg = iend + 1
end do
return

end subroutine getpatchdata

!  ------------------ getdata1 ------------------------

subroutine getdata1(file_unit,ipart,error)
implicit none

integer, intent(in) :: file_unit
integer, intent(out) :: ipart, error

integer :: lu10
real :: sarx, sary, swpar
integer :: i, j, k
integer ndum2
integer :: nspr, nv
integer :: ibar, jbar, kbar
real :: dummy
integer :: nb1, idummy

lu10 = file_unit
error=0

read(lu10,iostat=error) sarx,sary,swpar,ipart,ndum2
if(error.ne.0)return

read(lu10,iostat=error) ibar,jbar,kbar
if(error.ne.0)return

read(lu10,iostat=error) (dummy,i=1,ibar+1),(dummy,j=1,jbar+1),(dummy,k=1,kbar+1)
if(error.ne.0)return

read(lu10,iostat=error) nb1
if(error.ne.0)return

do i=1,nb1
  read(lu10,iostat=error) idummy, idummy, idummy, idummy, idummy, idummy,idummy
  if(error.ne.0)return
end do

read(lu10,iostat=error) nv
if(error.ne.0)return

do i=1,nv
  read(lu10,iostat=error) idummy, idummy, idummy, idummy, idummy, idummy,idummy
  if(error.ne.0)return
end do

read(lu10,iostat=error) nspr
if(error.ne.0)return

do i=1,nspr
  read(lu10,iostat=error) dummy,dummy,dummy
  if(error.ne.0)return
end do


return
end subroutine getdata1

!  ------------------ getslicefiledirection ------------------------

subroutine getslicefiledirection(is1,is2,iis1, iis2, js1,js2,ks1,ks2,idir,joff,koff,volslice)
implicit none
integer :: nxsp, nysp, nzsp
integer, intent(in) :: is1, js1, ks1
integer, intent(inout) :: is2, js2, ks2
integer, intent(out) :: iis1, iis2, idir, koff, joff, volslice
integer :: imin

nxsp = is2 + 1 - is1
nysp = js2 + 1 - js1
nzsp = ks2 + 1 - ks1
joff=0
koff=0
volslice=0
iis1 = is1
iis2 = is2
if(is1.ne.is2.and.js1.ne.js2.and.ks1.ne.ks2)then
  idir=1
  is2 = is1
  volslice=1
  return
endif
imin = min(nxsp,nysp,nzsp)
if(nxsp.eq.imin)then
  idir = 1
  is2 = is1
 elseif(nysp.eq.imin)then
  idir = 2
  js2 = js1
 else
  idir = 3
  ks2 = ks1
endif
if(is1.eq.is2.and.js1.eq.js2)then
   idir=1
   joff=1
  elseif(is1.eq.is2.and.ks1.eq.ks2)then
   idir=1
   koff=1
  elseif(js1.eq.js2.and.ks1.eq.ks2)then
   idir=2
   koff=1
endif
return
end subroutine getslicefiledirection

!  ------------------ writeslicedata ------------------------

subroutine writeslicedata(slicefilename,is1,is2,js1,js2,ks1,ks2,qdata,times,ntimes,redirect_flag)
implicit none

character(len=*),intent(in) :: slicefilename
integer, intent(in) :: is1, is2, js1, js2, ks1, ks2, redirect_flag
real, intent(in), dimension(*) :: qdata
real, intent(in), dimension(*) :: times
integer, intent(in) :: ntimes

integer :: error
character(len=30) :: longlbl, shortlbl, unitlbl
integer :: ibeg, iend, nframe
integer :: nxsp, nysp, nzsp
integer :: i,ii
integer :: file_unit


open(newunit=file_unit,file=trim(slicefilename),form="unformatted",action="write")

longlbl=" "
shortlbl=" "
unitlbl=" "

write(file_unit,iostat=error)longlbl
write(file_unit,iostat=error)shortlbl
write(file_unit,iostat=error)unitlbl

write(file_unit,iostat=error)is1, is2, js1, js2, ks1, ks2
nxsp = is2 + 1 - is1
nysp = js2 + 1 - js1
nzsp = ks2 + 1 - ks1
nframe=nxsp*nysp*nzsp
if(redirect_flag.eq.0)write(6,*)"outputt slice data to ",trim(slicefilename)
do i = 1, ntimes
  write(file_unit)times(i)
  ibeg=1+(i-1)*nframe
  iend=i*nframe
  write(file_unit)(qdata(ii),ii=ibeg,iend)
end do

close(file_unit)

return
end subroutine writeslicedata

!  ------------------ writeslicedata2 ------------------------

subroutine writeslicedata2(slicefilename,&
   longlabel,shortlabel,unitlabel,&
   is1,is2,js1,js2,ks1,ks2,qdata,times,ntimes)
implicit none

character(len=*),intent(in) :: slicefilename, longlabel, shortlabel, unitlabel
integer, intent(in) :: is1, is2, js1, js2, ks1, ks2
real, intent(in), dimension(*) :: qdata
real, intent(in), dimension(*) :: times
integer, intent(in) :: ntimes

integer :: file_unit
integer :: error
character(len=30) :: longlabel30, shortlabel30, unitlabel30
integer :: ibeg, iend, nframe
integer :: nxsp, nysp, nzsp
integer :: i,ii

open(newunit=file_unit,file=trim(slicefilename),form="unformatted",action="write")

longlabel30 = trim(longlabel)
shortlabel30 = trim(shortlabel)
unitlabel30 = trim(unitlabel)

write(file_unit,iostat=error)longlabel30
write(file_unit,iostat=error)shortlabel30
write(file_unit,iostat=error)unitlabel30

write(file_unit,iostat=error)is1, is2, js1, js2, ks1, ks2
nxsp = is2 + 1 - is1
nysp = js2 + 1 - js1
nzsp = ks2 + 1 - ks1
nframe=nxsp*nysp*nzsp
do i = 1, ntimes
  write(file_unit)times(i)
  ibeg=1+(i-1)*nframe
  iend=i*nframe
  write(file_unit)(qdata(ii),ii=ibeg,iend)
end do

close(file_unit)

return
end subroutine writeslicedata2

!  ------------------ getslicedata ------------------------

subroutine getslicedata(slicefilename,&
            is1,is2,js1,js2,ks1,ks2,idir,qmin,qmax,qdata,times,ntimes_old,ntimes,&
            sliceframestep,settmin_s,settmax_s,tmin_s,tmax_s,file_size)
use cio
implicit none

character(len=*), intent(in) :: slicefilename

integer, intent(in) :: ntimes_old, settmin_s, settmax_s, sliceframestep

real, intent(inout) :: qmin, qmax
real, intent(out), dimension(*) :: qdata, times

integer, intent(out) :: idir, is1, is2, js1, js2, ks1, ks2, file_size
integer, intent(inout) :: ntimes
real, intent(in) :: tmin_s, tmax_s

real, dimension(:,:,:), pointer :: qq

integer :: i,j,k
integer :: lu11, nsteps
logical :: exists
integer :: ip1, ip2, jp1, jp2, kp1, kp2
integer :: nxsp, nysp, nzsp
integer :: error, istart, irowstart
real :: timeval, time_max
character(len=30) :: longlbl, shortlbl, unitlbl
character(len=3) :: blank
logical :: load
integer :: ii, kk
integer :: joff, koff, volslice
integer :: count
integer :: iis1, iis2
integer, allocatable, dimension(:) :: sizes
integer :: nsizes

joff = 0
koff = 0
file_size = 0

inquire(file=trim(slicefilename),exist=exists)
if(exists)then
  open(newunit=lu11,file=trim(slicefilename),form="unformatted",action="read")
 else
  write(6,*)' the slice file ',trim(slicefilename),' does not exist'
  nsteps = 0
  return
endif

nsteps = 0
blank = '   '
longlbl=" "
shortlbl=" "
unitlbl=" "

allocate(sizes(3))
sizes(1) = 30
sizes(2) = 30
sizes(3) = 30
nsizes = 3

call ffseek(lu11,sizes,nsizes,seek_set,error)
deallocate(sizes)

read(lu11,iostat=error)ip1, ip2, jp1, jp2, kp1, kp2
file_size = 6*4
is1 = ip1
is2 = ip2
js1 = jp1
js2 = jp2
ks1 = kp1
ks2 = kp2
if(error.ne.0)then
  close(lu11)
  return
endif

nxsp = is2 + 1 - is1
nysp = js2 + 1 - js1
nzsp = ks2 + 1 - ks1
call getslicefiledirection(is1,is2,iis1,iis2,js1,js2,ks1,ks2,idir,joff,koff,volslice)

allocate(qq(nxsp,nysp+joff,nzsp+koff))

count=-1
time_max=-1000000.0
if(ntimes/=ntimes_old.and.ntimes_old>0)then
  allocate(sizes(2*ntimes_old))
  do i = 1, ntimes_old
    sizes(2*i-1) = 4
    sizes(2*i) = 4*nxsp*nysp*nzsp
  end do
  nsizes = 2*ntimes_old
  call ffseek(lu11,sizes,nsizes,seek_cur,error)
  deallocate(sizes)
  nsteps = ntimes_old
endif
do
  read(lu11,iostat=error)timeval
  file_size = file_size + 4
  if(error.ne.0)exit
  if((settmin_s.ne.0.and.timeval<tmin_s).or.timeval.le.time_max)then
    load = .false.
   else
    load = .true.
    time_max = timeval
  endif
  if(settmax_s.ne.0.and.timeval>tmax_s)exit
  read(lu11,iostat=error)(((qq(i,j,k),i=1,nxsp),j=1,nysp),k=1,nzsp)
  count=count+1
  if(mod(count,sliceframestep).ne.0)load = .false.
  if(koff.eq.1)then
    qq(1:nxsp,1:nysp,2)=qq(1:nxsp,1:nysp,1)
   elseif(joff.eq.1)then
    qq(1:nxsp,2,1:nzsp)=qq(1:nxsp,1,1:nzsp)
  endif
  if(error.ne.0.or.nsteps.ge.ntimes)go to 999
  if(.not.load)cycle
  nsteps = nsteps + 1
  times(nsteps) = timeval
  file_size = file_size + 4*nxsp*nysp*nzsp

  if(idir.eq.3)then
    istart = (nsteps-1)*nxsp*nysp
    do i = 1, nxsp
      irowstart = (i-1)*nysp
      ii = istart+irowstart
      qdata(ii+1:ii+nysp)=qq(i,1:nysp,1)
      qmax = max(qmax,maxval(qq(i,1:nysp,1)))
      qmin = min(qmin,minval(qq(i,1:nysp,1)))
    end do
  elseif(idir.eq.2)then
    istart = (nsteps-1)*nxsp*(nzsp+koff)
    do i = 1, nxsp
      irowstart = (i-1)*(nzsp+koff)
      kk = istart + irowstart
      qdata(kk+1:kk+nzsp+koff) = qq(i,1,1:nzsp+koff)
      qmax = max(qmax,maxval(qq(i,1,1:nzsp+koff)))
      qmin = min(qmin,minval(qq(i,1,1:nzsp+koff)))
    end do
  else
    istart = (nsteps-1)*(nysp+joff)*(nzsp+koff)*nxsp
    do i = 1, nxsp
    do j = 1, nysp+joff
      irowstart = (i-1)*nysp*(nzsp+koff)+(j-1)*(nzsp+koff)
      kk = istart + irowstart
      qdata(kk+1:kk+nzsp+koff) = qq(i,j,1:nzsp+koff)
      qmax = max(qmax,maxval(qq(i,j,1:nzsp+koff)))
      qmin = min(qmin,minval(qq(i,j,1:nzsp+koff)))
    end do
    end do
  endif

end do

999 continue
ks2 = ks2 + koff
js2 = js2 + joff
ntimes=nsteps
deallocate(qq)
close(lu11)

return
end subroutine getslicedata

!  ------------------ getsliceframe ------------------------

subroutine getsliceframe(lu11,is1,is2,js1,js2,ks1,ks2,time,qframe,testslice,error)
implicit none

real, intent(out), dimension(*) :: qframe
real, intent(out) :: time
integer, intent(out) :: error
integer, intent(in) :: lu11, is1, is2, js1, js2, ks1, ks2
integer, intent(in) :: testslice

integer :: i,j,k
integer :: nxsp, nysp, nzsp
real :: val,factor
integer :: index
real :: ii, jj, kk

nxsp = is2 + 1 - is1
nysp = js2 + 1 - js1
nzsp = ks2 + 1 - ks1

read(lu11,iostat=error)time
if(error.ne.0)return
read(lu11,iostat=error)(((qframe(1+i+j*nxsp+k*nxsp*nysp),i=0,nxsp-1),j=0,nysp-1),k=0,nzsp-1)
if(testslice.eq.1.or.testslice.eq.2)then
  factor=1.0
  if(testslice.eq.2)factor=1.1
  do k = 0, nzsp-1
    kk = 2.0*((nzsp-1)/2.0-k)/(nzsp-1.0)
    do j = 0, nysp-1
      jj = 2.0*((nysp-1)/2.0-j)/(nysp-1.0)
      do i = 0, nxsp-1
        ii = 2.0*((nxsp-1)/2.0-i)/(nxsp-1.0)
        val = factor*(time-20.0)*(ii*ii + jj*jj + kk*kk)/20.0
        index = 1+i+j*nxsp+k*nxsp*nysp
        qframe(index) = val
      end do
    end do
  end do
endif

return
end subroutine getsliceframe

!  ------------------ endianout ------------------------

subroutine endianout(endianfilename)
implicit none
character(len=*) :: endianfilename
integer :: one
integer :: file_unit

open(newunit=file_unit,file=trim(endianfilename),form="unformatted")
one=1
write(file_unit)one
close(file_unit)
return
end subroutine endianout

!  ------------------ outsliceheader ------------------------

subroutine outsliceheader(slicefilename,fileunit,ip1, ip2, jp1, jp2, kp1, kp2, error)
implicit none

character(len=*) :: slicefilename
integer, intent(out) :: fileunit
integer, intent(in) :: ip1, ip2, jp1, jp2, kp1, kp2
integer, intent(out) :: error

character(len=30) :: longlbl, shortlbl, unitlbl

open(newunit=fileunit,file=trim(slicefilename),form="unformatted")

longlbl= "long                          "
shortlbl="short                         "
unitlbl= "unit                          "
write(fileunit,iostat=error)longlbl
write(fileunit,iostat=error)shortlbl
write(fileunit,iostat=error)unitlbl

write(fileunit,iostat=error)ip1, ip2, jp1, jp2, kp1, kp2

end subroutine outsliceheader

!  ------------------ outsliceframe ------------------------

subroutine outsliceframe(lu11,is1,is2,js1,js2,ks1,ks2,time,qframe,error)
implicit none

real, intent(in), dimension(*) :: qframe
real, intent(in) :: time
integer, intent(out) :: error
integer, intent(in) :: lu11, is1, is2, js1, js2, ks1, ks2

integer :: i,j,k
integer :: nxsp, nysp, nzsp

nxsp = is2 + 1 - is1
nysp = js2 + 1 - js1
nzsp = ks2 + 1 - ks1

write(lu11,iostat=error)time
if(error.ne.0)return
write(lu11,iostat=error)(((qframe(1+i+j*nxsp+k*nxsp*nysp),i=0,nxsp-1),j=0,nysp-1),k=0,nzsp-1)

return
end subroutine outsliceframe

!  ------------------ outboundaryheader ------------------------

subroutine outboundaryheader(boundaryfilename,boundaryunitnumber,npatches,pi1,pi2,pj1,pj2,pk1,pk2,patchdir,error)
implicit none

character(len=*), intent(in) :: boundaryfilename
integer, intent(in) :: npatches
integer, intent(out) :: boundaryunitnumber
integer, intent(in), dimension(npatches) :: pi1, pi2, pj1, pj2, pk1, pk2, patchdir
integer, intent(out) :: error

character(len=30) :: blank
integer :: n

error=0
open(newunit=boundaryunitnumber,file=trim(boundaryfilename),form="unformatted",action="write")

blank="                              "
write(boundaryunitnumber)blank
write(boundaryunitnumber)blank
write(boundaryunitnumber)blank
write(boundaryunitnumber)npatches

do n = 1, npatches
  write(boundaryunitnumber)pi1(n), pi2(n), pj1(n), pj2(n), pk1(n), pk2(n), patchdir(n)
end do

return
end subroutine outboundaryheader

!  ------------------ outpatchframe ------------------------

subroutine outpatchframe(lunit,npatch,pi1,pi2,pj1,pj2,pk1,pk2,patchtime,pqq,error)
implicit none

integer, intent(in) :: npatch,lunit
integer, intent(in), dimension(*) :: pi1, pi2, pj1, pj2, pk1, pk2
real, intent(in), dimension(*) :: pqq
integer, intent(out) :: error
real, intent(in) :: patchtime

integer :: i, i1, i2, j1, j2, k1, k2, size, ibeg, iend, lu15, ii

error=0
lu15 = lunit
write(lu15)patchtime
ibeg = 1
do i = 1, npatch
  i1 = pi1(i)
  i2 = pi2(i)
  j1 = pj1(i)
  j2 = pj2(i)
  k1 = pk1(i)
  k2 = pk2(i)
  size = (i2+1-i1)*(j2+1-j1)*(k2+1-k1)
  iend = ibeg + size - 1
  write(lu15)(pqq(ii),ii=ibeg,iend)
  ibeg = iend + 1
end do
return

end subroutine outpatchframe

!  ------------------ getplot3dq ------------------------

subroutine getplot3dq(qfilename,nx,ny,nz,qq,error,isotest)
implicit none

character(len=*) :: qfilename
integer, intent(in) :: nx, ny, nz
integer, intent(out) :: error
real, dimension(nx,ny,nz,5)  :: qq
integer, intent(in) :: isotest

real :: dum1, dum2, dum3, dum4
logical :: exists
integer :: error2
real :: dummy, qval

integer :: nxpts, nypts, nzpts
integer :: i, j, k, n

integer :: u_in

if(isotest.eq.0)then
  error=0
  inquire(file=qfilename,exist=exists)
  if(exists)then
    open(newunit=u_in,file=qfilename,form="unformatted",action="read",iostat=error2)
   else
    write(6,*)' The file name, ',trim(qfilename),' does not exist'
    read(5,*)dummy
    stop
  endif

  read(u_in,iostat=error)nxpts, nypts, nzpts
  if(nx.eq.nxpts.and.ny.eq.nypts.and.nz.eq.nzpts)then
    read(u_in,iostat=error)dum1, dum2, dum3, dum4
    read(u_in,iostat=error)((((qq(i,j,k,n),i=1,nxpts),j=1,nypts),k=1,nzpts),n=1,5)
   else
    error = 1
    write(6,*)" *** Fatal error in getplot3dq ***"
    write(6,*)" Grid size found in plot3d file was:",nxpts,nypts,nzpts
    write(6,*)" Was expecting:",nx,ny,nz
    stop
  endif
  close(u_in)
 else
    do i = 1, nx
    do j = 1, ny
    do k = 1, nz
      qval = (i-nx/2)**2 + (j-ny/2)**2 + (k-nz/2)**2
      qval = sqrt(qval)
      if(isotest.eq.1)then
        qq(i,j,k,1) = 0.0
        qq(i,j,k,2) = 0.0
        qq(i,j,k,3:5) = qval
      endif
      if(isotest.eq.2)then
        qq(i,j,k,1)=qval
        qq(i,j,k,2)=1.1*qval
        qq(i,j,k,3:5)=1.1*qval
      endif
    end do
    end do
  end do
  error = 0
endif
close(u_in)
return
end subroutine getplot3dq

!  ------------------ plot3dout ------------------------

subroutine plot3dout(outfile, nx, ny, nz, qout, error3)
implicit none

character(len=*), intent(in) :: outfile
integer, intent(in) :: nx, ny, nz
real, dimension(nx,ny,nz,5)  :: qout
integer, intent(out) :: error3

integer :: u_out
integer :: i, j, k, n
real :: dummy

error3 = 0

dummy = 0.0
open(newunit=u_out,file=outfile,form="unformatted",action="write",iostat=error3)
if(error3.ne.0)return

write(u_out,iostat=error3)nx, ny, nz
write(u_out,iostat=error3)dummy, dummy, dummy, dummy
write(u_out,iostat=error3)((((qout(i,j,k,n),i=1,nx),j=1,ny),k=1,nz),n=1,5)
close(u_out)

return
end subroutine plot3dout

SUBROUTINE color2rgb(RGB,COLOR)
implicit none

! Translate character string of a color name to RGB value

INTEGER :: RGB(3)
CHARACTER(len=*) :: COLOR

SELECT CASE(COLOR)
CASE ('ALICE BLUE');RGB = (/240,248,255/)
CASE ('ANTIQUE WHITE');RGB = (/250,235,215/)
CASE ('ANTIQUE WHITE 1');RGB = (/255,239,219/)
CASE ('ANTIQUE WHITE 2');RGB = (/238,223,204/)
CASE ('ANTIQUE WHITE 3');RGB = (/205,192,176/)
CASE ('ANTIQUE WHITE 4');RGB = (/139,131,120/)
CASE ('AQUAMARINE');RGB = (/127,255,212/)
CASE ('AQUAMARINE 1');RGB = (/118,238,198/)
CASE ('AQUAMARINE 2');RGB = (/102,205,170/)
CASE ('AQUAMARINE 3');RGB = (/69,139,116/)
CASE ('AZURE');RGB = (/240,255,255/)
CASE ('AZURE 1');RGB = (/224,238,238/)
CASE ('AZURE 2');RGB = (/193,205,205/)
CASE ('AZURE 3');RGB = (/131,139,139/)
CASE ('BANANA');RGB = (/227,207,87/)
CASE ('BEIGE');RGB = (/245,245,220/)
CASE ('BISQUE');RGB = (/255,228,196/)
CASE ('BISQUE 1');RGB = (/238,213,183/)
CASE ('BISQUE 2');RGB = (/205,183,158/)
CASE ('BISQUE 3');RGB = (/139,125,107/)
CASE ('BLACK');RGB = (/0,0,0/)
CASE ('BLANCHED ALMOND');RGB = (/255,235,205/)
CASE ('BLUE');RGB = (/0,0,255/)
CASE ('BLUE 2');RGB = (/0,0,238/)
CASE ('BLUE 3');RGB = (/0,0,205/)
CASE ('BLUE 4');RGB = (/0,0,139/)
CASE ('BLUE VIOLET');RGB = (/138,43,226/)
CASE ('BRICK');RGB = (/156,102,31/)
CASE ('BROWN');RGB = (/165,42,42/)
CASE ('BROWN 1');RGB = (/255,64,64/)
CASE ('BROWN 2');RGB = (/238,59,59/)
CASE ('BROWN 3');RGB = (/205,51,51/)
CASE ('BROWN 4');RGB = (/139,35,35/)
CASE ('BURLY WOOD');RGB = (/222,184,135/)
CASE ('BURLY WOOD 1');RGB = (/255,211,155/)
CASE ('BURLY WOOD 2');RGB = (/238,197,145/)
CASE ('BURLY WOOD 3');RGB = (/205,170,125/)
CASE ('BURLY WOOD 4');RGB = (/139,115,85/)
CASE ('BURNT ORANGE');RGB = (/204,85,0/)
CASE ('BURNT SIENNA');RGB = (/138,54,15/)
CASE ('BURNT UMBER');RGB = (/138,51,36/)
CASE ('CADET BLUE');RGB = (/95,158,160/)
CASE ('CADET BLUE 1');RGB = (/152,245,255/)
CASE ('CADET BLUE 2');RGB = (/142,229,238/)
CASE ('CADET BLUE 3');RGB = (/122,197,205/)
CASE ('CADET BLUE 4');RGB = (/83,134,139/)
CASE ('CADMIUM ORANGE');RGB = (/255,97,3/)
CASE ('CADMIUM YELLOW');RGB = (/255,153,18/)
CASE ('CARROT');RGB = (/237,145,33/)
CASE ('CHARTREUSE');RGB = (/127,255,0/)
CASE ('CHARTREUSE 1');RGB = (/118,238,0/)
CASE ('CHARTREUSE 2');RGB = (/102,205,0/)
CASE ('CHARTREUSE 3');RGB = (/69,139,0/)
CASE ('CHOCOLATE');RGB = (/210,105,30/)
CASE ('CHOCOLATE 1');RGB = (/255,127,36/)
CASE ('CHOCOLATE 2');RGB = (/238,118,33/)
CASE ('CHOCOLATE 3');RGB = (/205,102,29/)
CASE ('CHOCOLATE 4');RGB = (/139,69,19/)
CASE ('COBALT');RGB = (/61,89,171/)
CASE ('COBALT GREEN');RGB = (/61,145,64/)
CASE ('COLD GREY');RGB = (/128,138,135/)
CASE ('CORAL');RGB = (/255,127,80/)
CASE ('CORAL 1');RGB = (/255,114,86/)
CASE ('CORAL 2');RGB = (/238,106,80/)
CASE ('CORAL 3');RGB = (/205,91,69/)
CASE ('CORAL 4');RGB = (/139,62,47/)
CASE ('CORNFLOWER BLUE');RGB = (/100,149,237/)
CASE ('CORNSILK');RGB = (/255,248,220/)
CASE ('CORNSILK 1');RGB = (/238,232,205/)
CASE ('CORNSILK 2');RGB = (/205,200,177/)
CASE ('CORNSILK 3');RGB = (/139,136,120/)
CASE ('CRIMSON');RGB = (/220,20,60/)
CASE ('CYAN');RGB = (/0,255,255/)
CASE ('CYAN 2');RGB = (/0,238,238/)
CASE ('CYAN 3');RGB = (/0,205,205/)
CASE ('CYAN 4');RGB = (/0,139,139/)
CASE ('DARK GOLDENROD');RGB = (/184,134,11/)
CASE ('DARK GOLDENROD 1');RGB = (/255,185,15/)
CASE ('DARK GOLDENROD 2');RGB = (/238,173,14/)
CASE ('DARK GOLDENROD 3');RGB = (/205,149,12/)
CASE ('DARK GOLDENROD 4');RGB = (/139,101,8/)
CASE ('DARK GRAY');RGB = (/169,169,169/)
CASE ('DARK GREEN');RGB = (/0,100,0/)
CASE ('DARK KHAKI');RGB = (/189,183,107/)
CASE ('DARK OLIVE GREEN');RGB = (/85,107,47/)
CASE ('DARK OLIVE GREEN 1');RGB = (/202,255,112/)
CASE ('DARK OLIVE GREEN 2');RGB = (/188,238,104/)
CASE ('DARK OLIVE GREEN 3');RGB = (/162,205,90/)
CASE ('DARK OLIVE GREEN 4');RGB = (/110,139,61/)
CASE ('DARK ORANGE');RGB = (/255,140,0/)
CASE ('DARK ORANGE 1');RGB = (/255,127,0/)
CASE ('DARK ORANGE 2');RGB = (/238,118,0/)
CASE ('DARK ORANGE 3');RGB = (/205,102,0/)
CASE ('DARK ORANGE 4');RGB = (/139,69,0/)
CASE ('DARK ORCHID');RGB = (/153,50,204/)
CASE ('DARK ORCHID 1');RGB = (/191,62,255/)
CASE ('DARK ORCHID 2');RGB = (/178,58,238/)
CASE ('DARK ORCHID 3');RGB = (/154,50,205/)
CASE ('DARK ORCHID 4');RGB = (/104,34,139/)
CASE ('DARK SALMON');RGB = (/233,150,122/)
CASE ('DARK SEA GREEN');RGB = (/143,188,143/)
CASE ('DARK SEA GREEN 1');RGB = (/193,255,193/)
CASE ('DARK SEA GREEN 2');RGB = (/180,238,180/)
CASE ('DARK SEA GREEN 3');RGB = (/155,205,155/)
CASE ('DARK SEA GREEN 4');RGB = (/105,139,105/)
CASE ('DARK SLATE BLUE');RGB = (/72,61,139/)
CASE ('DARK SLATE GRAY');RGB = (/47,79,79/)
CASE ('DARK SLATE GRAY 1');RGB = (/151,255,255/)
CASE ('DARK SLATE GRAY 2');RGB = (/141,238,238/)
CASE ('DARK SLATE GRAY 3');RGB = (/121,205,205/)
CASE ('DARK SLATE GRAY 4');RGB = (/82,139,139/)
CASE ('DARK TURQUOISE');RGB = (/0,206,209/)
CASE ('DARK VIOLET');RGB = (/148,0,211/)
CASE ('DEEP PINK');RGB = (/255,20,147/)
CASE ('DEEP PINK 1');RGB = (/238,18,137/)
CASE ('DEEP PINK 2');RGB = (/205,16,118/)
CASE ('DEEP PINK 3');RGB = (/139,10,80/)
CASE ('DEEP SKYBLUE');RGB = (/0,191,255/)
CASE ('DEEP SKYBLUE 1');RGB = (/0,178,238/)
CASE ('DEEP SKYBLUE 2');RGB = (/0,154,205/)
CASE ('DEEP SKYBLUE 3');RGB = (/0,104,139/)
CASE ('DIM GRAY');RGB = (/105,105,105/)
CASE ('DODGERBLUE');RGB = (/30,144,255/)
CASE ('DODGERBLUE 1');RGB = (/28,134,238/)
CASE ('DODGERBLUE 2');RGB = (/24,116,205/)
CASE ('DODGERBLUE 3');RGB = (/16,78,139/)
CASE ('EGGSHELL');RGB = (/252,230,201/)
CASE ('EMERALD GREEN');RGB = (/0,201,87/)
CASE ('FIREBRICK');RGB = (/178,34,34/)
CASE ('FIREBRICK 1');RGB = (/255,48,48/)
CASE ('FIREBRICK 2');RGB = (/238,44,44/)
CASE ('FIREBRICK 3');RGB = (/205,38,38/)
CASE ('FIREBRICK 4');RGB = (/139,26,26/)
CASE ('FLESH');RGB = (/255,125,64/)
CASE ('FLORAL WHITE');RGB = (/255,250,240/)
CASE ('FOREST GREEN');RGB = (/34,139,34/)
CASE ('GAINSBORO');RGB = (/220,220,220/)
CASE ('GHOST WHITE');RGB = (/248,248,255/)
CASE ('GOLD');RGB = (/255,215,0/)
CASE ('GOLD 1');RGB = (/238,201,0/)
CASE ('GOLD 2');RGB = (/205,173,0/)
CASE ('GOLD 3');RGB = (/139,117,0/)
CASE ('GOLDENROD');RGB = (/218,165,32/)
CASE ('GOLDENROD 1');RGB = (/255,193,37/)
CASE ('GOLDENROD 2');RGB = (/238,180,34/)
CASE ('GOLDENROD 3');RGB = (/205,155,29/)
CASE ('GOLDENROD 4');RGB = (/139,105,20/)
CASE ('GRAY');RGB = (/128,128,128/)
CASE ('GRAY 1');RGB = (/3,3,3/)
CASE ('GRAY 10');RGB = (/26,26,26/)
CASE ('GRAY 11');RGB = (/28,28,28/)
CASE ('GRAY 12');RGB = (/31,31,31/)
CASE ('GRAY 13');RGB = (/33,33,33/)
CASE ('GRAY 14');RGB = (/36,36,36/)
CASE ('GRAY 15');RGB = (/38,38,38/)
CASE ('GRAY 16');RGB = (/41,41,41/)
CASE ('GRAY 17');RGB = (/43,43,43/)
CASE ('GRAY 18');RGB = (/46,46,46/)
CASE ('GRAY 19');RGB = (/48,48,48/)
CASE ('GRAY 2');RGB = (/5,5,5/)
CASE ('GRAY 20');RGB = (/51,51,51/)
CASE ('GRAY 21');RGB = (/54,54,54/)
CASE ('GRAY 22');RGB = (/56,56,56/)
CASE ('GRAY 23');RGB = (/59,59,59/)
CASE ('GRAY 24');RGB = (/61,61,61/)
CASE ('GRAY 25');RGB = (/64,64,64/)
CASE ('GRAY 26');RGB = (/66,66,66/)
CASE ('GRAY 27');RGB = (/69,69,69/)
CASE ('GRAY 28');RGB = (/71,71,71/)
CASE ('GRAY 29');RGB = (/74,74,74/)
CASE ('GRAY 3');RGB = (/8,8,8/)
CASE ('GRAY 30');RGB = (/77,77,77/)
CASE ('GRAY 31');RGB = (/79,79,79/)
CASE ('GRAY 32');RGB = (/82,82,82/)
CASE ('GRAY 33');RGB = (/84,84,84/)
CASE ('GRAY 34');RGB = (/87,87,87/)
CASE ('GRAY 35');RGB = (/89,89,89/)
CASE ('GRAY 36');RGB = (/92,92,92/)
CASE ('GRAY 37');RGB = (/94,94,94/)
CASE ('GRAY 38');RGB = (/97,97,97/)
CASE ('GRAY 39');RGB = (/99,99,99/)
CASE ('GRAY 4');RGB = (/10,10,10/)
CASE ('GRAY 40');RGB = (/102,102,102/)
CASE ('GRAY 42');RGB = (/107,107,107/)
CASE ('GRAY 43');RGB = (/110,110,110/)
CASE ('GRAY 44');RGB = (/112,112,112/)
CASE ('GRAY 45');RGB = (/115,115,115/)
CASE ('GRAY 46');RGB = (/117,117,117/)
CASE ('GRAY 47');RGB = (/120,120,120/)
CASE ('GRAY 48');RGB = (/122,122,122/)
CASE ('GRAY 49');RGB = (/125,125,125/)
CASE ('GRAY 5');RGB = (/13,13,13/)
CASE ('GRAY 50');RGB = (/127,127,127/)
CASE ('GRAY 51');RGB = (/130,130,130/)
CASE ('GRAY 52');RGB = (/133,133,133/)
CASE ('GRAY 53');RGB = (/135,135,135/)
CASE ('GRAY 54');RGB = (/138,138,138/)
CASE ('GRAY 55');RGB = (/140,140,140/)
CASE ('GRAY 56');RGB = (/143,143,143/)
CASE ('GRAY 57');RGB = (/145,145,145/)
CASE ('GRAY 58');RGB = (/148,148,148/)
CASE ('GRAY 59');RGB = (/150,150,150/)
CASE ('GRAY 6');RGB = (/15,15,15/)
CASE ('GRAY 60');RGB = (/153,153,153/)
CASE ('GRAY 61');RGB = (/156,156,156/)
CASE ('GRAY 62');RGB = (/158,158,158/)
CASE ('GRAY 63');RGB = (/161,161,161/)
CASE ('GRAY 64');RGB = (/163,163,163/)
CASE ('GRAY 65');RGB = (/166,166,166/)
CASE ('GRAY 66');RGB = (/168,168,168/)
CASE ('GRAY 67');RGB = (/171,171,171/)
CASE ('GRAY 68');RGB = (/173,173,173/)
CASE ('GRAY 69');RGB = (/176,176,176/)
CASE ('GRAY 7');RGB = (/18,18,18/)
CASE ('GRAY 70');RGB = (/179,179,179/)
CASE ('GRAY 71');RGB = (/181,181,181/)
CASE ('GRAY 72');RGB = (/184,184,184/)
CASE ('GRAY 73');RGB = (/186,186,186/)
CASE ('GRAY 74');RGB = (/189,189,189/)
CASE ('GRAY 75');RGB = (/191,191,191/)
CASE ('GRAY 76');RGB = (/194,194,194/)
CASE ('GRAY 77');RGB = (/196,196,196/)
CASE ('GRAY 78');RGB = (/199,199,199/)
CASE ('GRAY 79');RGB = (/201,201,201/)
CASE ('GRAY 8');RGB = (/20,20,20/)
CASE ('GRAY 80');RGB = (/204,204,204/)
CASE ('GRAY 81');RGB = (/207,207,207/)
CASE ('GRAY 82');RGB = (/209,209,209/)
CASE ('GRAY 83');RGB = (/212,212,212/)
CASE ('GRAY 84');RGB = (/214,214,214/)
CASE ('GRAY 85');RGB = (/217,217,217/)
CASE ('GRAY 86');RGB = (/219,219,219/)
CASE ('GRAY 87');RGB = (/222,222,222/)
CASE ('GRAY 88');RGB = (/224,224,224/)
CASE ('GRAY 89');RGB = (/227,227,227/)
CASE ('GRAY 9');RGB = (/23,23,23/)
CASE ('GRAY 90');RGB = (/229,229,229/)
CASE ('GRAY 91');RGB = (/232,232,232/)
CASE ('GRAY 92');RGB = (/235,235,235/)
CASE ('GRAY 93');RGB = (/237,237,237/)
CASE ('GRAY 94');RGB = (/240,240,240/)
CASE ('GRAY 95');RGB = (/242,242,242/)
CASE ('GRAY 97');RGB = (/247,247,247/)
CASE ('GRAY 98');RGB = (/250,250,250/)
CASE ('GRAY 99');RGB = (/252,252,252/)
CASE ('GREEN');RGB = (/0,255,0/)
CASE ('GREEN 2');RGB = (/0,238,0/)
CASE ('GREEN 3');RGB = (/0,205,0/)
CASE ('GREEN 4');RGB = (/0,139,0/)
CASE ('GREEN YELLOW');RGB = (/173,255,47/)
CASE ('HONEYDEW');RGB = (/240,255,240/)
CASE ('HONEYDEW 1');RGB = (/224,238,224/)
CASE ('HONEYDEW 2');RGB = (/193,205,193/)
CASE ('HONEYDEW 3');RGB = (/131,139,131/)
CASE ('HOT PINK');RGB = (/255,105,180/)
CASE ('HOT PINK 1');RGB = (/255,110,180/)
CASE ('HOT PINK 2');RGB = (/238,106,167/)
CASE ('HOT PINK 3');RGB = (/205,96,144/)
CASE ('HOT PINK 4');RGB = (/139,58,98/)
CASE ('INDIAN RED');RGB = (/205,92,92/)
CASE ('INDIAN RED 1');RGB = (/255,106,106/)
CASE ('INDIAN RED 2');RGB = (/238,99,99/)
CASE ('INDIAN RED 3');RGB = (/205,85,85/)
CASE ('INDIAN RED 4');RGB = (/139,58,58/)
CASE ('INDIGO');RGB = (/75,0,130/)
CASE ('IVORY');RGB = (/255,255,240/)
CASE ('IVORY 1');RGB = (/238,238,224/)
CASE ('IVORY 2');RGB = (/205,205,193/)
CASE ('IVORY 3');RGB = (/139,139,131/)
CASE ('IVORY BLACK');RGB = (/41,36,33/)
CASE ('KELLY GREEN');RGB = (/0,128,0/)
CASE ('KHAKI');RGB = (/240,230,140/)
CASE ('KHAKI 1');RGB = (/255,246,143/)
CASE ('KHAKI 2');RGB = (/238,230,133/)
CASE ('KHAKI 3');RGB = (/205,198,115/)
CASE ('KHAKI 4');RGB = (/139,134,78/)
CASE ('LAVENDER');RGB = (/230,230,250/)
CASE ('LAVENDER BLUSH');RGB = (/255,240,245/)
CASE ('LAVENDER BLUSH 1');RGB = (/238,224,229/)
CASE ('LAVENDER BLUSH 2');RGB = (/205,193,197/)
CASE ('LAVENDER BLUSH 3');RGB = (/139,131,134/)
CASE ('LAWN GREEN');RGB = (/124,252,0/)
CASE ('LEMON CHIFFON');RGB = (/255,250,205/)
CASE ('LEMON CHIFFON 1');RGB = (/238,233,191/)
CASE ('LEMON CHIFFON 2');RGB = (/205,201,165/)
CASE ('LEMON CHIFFON 3');RGB = (/139,137,112/)
CASE ('LIGHT BLUE');RGB = (/173,216,230/)
CASE ('LIGHT BLUE 1');RGB = (/191,239,255/)
CASE ('LIGHT BLUE 2');RGB = (/178,223,238/)
CASE ('LIGHT BLUE 3');RGB = (/154,192,205/)
CASE ('LIGHT BLUE 4');RGB = (/104,131,139/)
CASE ('LIGHT CORAL');RGB = (/240,128,128/)
CASE ('LIGHT CYAN');RGB = (/224,255,255/)
CASE ('LIGHT CYAN 1');RGB = (/209,238,238/)
CASE ('LIGHT CYAN 2');RGB = (/180,205,205/)
CASE ('LIGHT CYAN 3');RGB = (/122,139,139/)
CASE ('LIGHT GOLDENROD');RGB = (/255,236,139/)
CASE ('LIGHT GOLDENROD 1');RGB = (/238,220,130/)
CASE ('LIGHT GOLDENROD 2');RGB = (/205,190,112/)
CASE ('LIGHT GOLDENROD 3');RGB = (/139,129,76/)
CASE ('LIGHT GOLDENROD YELLOW');RGB = (/250,250,210/)
CASE ('LIGHT GREY');RGB = (/211,211,211/)
CASE ('LIGHT PINK');RGB = (/255,182,193/)
CASE ('LIGHT PINK 1');RGB = (/255,174,185/)
CASE ('LIGHT PINK 2');RGB = (/238,162,173/)
CASE ('LIGHT PINK 3');RGB = (/205,140,149/)
CASE ('LIGHT PINK 4');RGB = (/139,95,101/)
CASE ('LIGHT SALMON');RGB = (/255,160,122/)
CASE ('LIGHT SALMON 1');RGB = (/238,149,114/)
CASE ('LIGHT SALMON 2');RGB = (/205,129,98/)
CASE ('LIGHT SALMON 3');RGB = (/139,87,66/)
CASE ('LIGHT SEA GREEN');RGB = (/32,178,170/)
CASE ('LIGHT SKY BLUE');RGB = (/135,206,250/)
CASE ('LIGHT SKY BLUE 1');RGB = (/176,226,255/)
CASE ('LIGHT SKY BLUE 2');RGB = (/164,211,238/)
CASE ('LIGHT SKY BLUE 3');RGB = (/141,182,205/)
CASE ('LIGHT SKY BLUE 4');RGB = (/96,123,139/)
CASE ('LIGHT SLATE BLUE');RGB = (/132,112,255/)
CASE ('LIGHT SLATE GRAY');RGB = (/119,136,153/)
CASE ('LIGHT STEEL BLUE');RGB = (/176,196,222/)
CASE ('LIGHT STEEL BLUE 1');RGB = (/202,225,255/)
CASE ('LIGHT STEEL BLUE 2');RGB = (/188,210,238/)
CASE ('LIGHT STEEL BLUE 3');RGB = (/162,181,205/)
CASE ('LIGHT STEEL BLUE 4');RGB = (/110,123,139/)
CASE ('LIGHT YELLOW 1');RGB = (/255,255,224/)
CASE ('LIGHT YELLOW 2');RGB = (/238,238,209/)
CASE ('LIGHT YELLOW 3');RGB = (/205,205,180/)
CASE ('LIGHT YELLOW 4');RGB = (/139,139,122/)
CASE ('LIME GREEN');RGB = (/50,205,50/)
CASE ('LINEN');RGB = (/250,240,230/)
CASE ('MAGENTA');RGB = (/255,0,255/)
CASE ('MAGENTA 2');RGB = (/238,0,238/)
CASE ('MAGENTA 3');RGB = (/205,0,205/)
CASE ('MAGENTA 4');RGB = (/139,0,139/)
CASE ('MANGANESE BLUE');RGB = (/3,168,158/)
CASE ('MAROON');RGB = (/128,0,0/)
CASE ('MAROON 1');RGB = (/255,52,179/)
CASE ('MAROON 2');RGB = (/238,48,167/)
CASE ('MAROON 3');RGB = (/205,41,144/)
CASE ('MAROON 4');RGB = (/139,28,98/)
CASE ('MEDIUM ORCHID');RGB = (/186,85,211/)
CASE ('MEDIUM ORCHID 1');RGB = (/224,102,255/)
CASE ('MEDIUM ORCHID 2');RGB = (/209,95,238/)
CASE ('MEDIUM ORCHID 3');RGB = (/180,82,205/)
CASE ('MEDIUM ORCHID 4');RGB = (/122,55,139/)
CASE ('MEDIUM PURPLE');RGB = (/147,112,219/)
CASE ('MEDIUM PURPLE 1');RGB = (/171,130,255/)
CASE ('MEDIUM PURPLE 2');RGB = (/159,121,238/)
CASE ('MEDIUM PURPLE 3');RGB = (/137,104,205/)
CASE ('MEDIUM PURPLE 4');RGB = (/93,71,139/)
CASE ('MEDIUM SEA GREEN');RGB = (/60,179,113/)
CASE ('MEDIUM SLATE BLUE');RGB = (/123,104,238/)
CASE ('MEDIUM SPRING GREEN');RGB = (/0,250,154/)
CASE ('MEDIUM TURQUOISE');RGB = (/72,209,204/)
CASE ('MEDIUM VIOLET RED');RGB = (/199,21,133/)
CASE ('MELON');RGB = (/227,168,105/)
CASE ('MIDNIGHT BLUE');RGB = (/25,25,112/)
CASE ('MINT');RGB = (/189,252,201/)
CASE ('MINT CREAM');RGB = (/245,255,250/)
CASE ('MISTY ROSE');RGB = (/255,228,225/)
CASE ('MISTY ROSE 1');RGB = (/238,213,210/)
CASE ('MISTY ROSE 2');RGB = (/205,183,181/)
CASE ('MISTY ROSE 3');RGB = (/139,125,123/)
CASE ('MOCCASIN');RGB = (/255,228,181/)
CASE ('NAVAJO WHITE');RGB = (/255,222,173/)
CASE ('NAVAJO WHITE 1');RGB = (/238,207,161/)
CASE ('NAVAJO WHITE 2');RGB = (/205,179,139/)
CASE ('NAVAJO WHITE 3');RGB = (/139,121,94/)
CASE ('NAVY');RGB = (/0,0,128/)
CASE ('OLD LACE');RGB = (/253,245,230/)
CASE ('OLIVE');RGB = (/128,128,0/)
CASE ('OLIVE DRAB');RGB = (/192,255,62/)
CASE ('OLIVE DRAB 1');RGB = (/179,238,58/)
CASE ('OLIVE DRAB 2');RGB = (/154,205,50/)
CASE ('OLIVE DRAB 3');RGB = (/105,139,34/)
CASE ('ORANGE');RGB = (/255,128,0/)
CASE ('ORANGE 1');RGB = (/255,165,0/)
CASE ('ORANGE 2');RGB = (/238,154,0/)
CASE ('ORANGE 3');RGB = (/205,133,0/)
CASE ('ORANGE 4');RGB = (/139,90,0/)
CASE ('ORANGE RED');RGB = (/255,69,0/)
CASE ('ORANGE RED 1');RGB = (/238,64,0/)
CASE ('ORANGE RED 2');RGB = (/205,55,0/)
CASE ('ORANGE RED 3');RGB = (/139,37,0/)
CASE ('ORCHID');RGB = (/218,112,214/)
CASE ('ORCHID 1');RGB = (/255,131,250/)
CASE ('ORCHID 2');RGB = (/238,122,233/)
CASE ('ORCHID 3');RGB = (/205,105,201/)
CASE ('ORCHID 4');RGB = (/139,71,137/)
CASE ('PALE GOLDENROD');RGB = (/238,232,170/)
CASE ('PALE GREEN');RGB = (/152,251,152/)
CASE ('PALE GREEN 1');RGB = (/154,255,154/)
CASE ('PALE GREEN 2');RGB = (/144,238,144/)
CASE ('PALE GREEN 3');RGB = (/124,205,124/)
CASE ('PALE GREEN 4');RGB = (/84,139,84/)
CASE ('PALE TURQUOISE');RGB = (/187,255,255/)
CASE ('PALE TURQUOISE 1');RGB = (/174,238,238/)
CASE ('PALE TURQUOISE 2');RGB = (/150,205,205/)
CASE ('PALE TURQUOISE 3');RGB = (/102,139,139/)
CASE ('PALE VIOLET RED');RGB = (/219,112,147/)
CASE ('PALE VIOLET RED 1');RGB = (/255,130,171/)
CASE ('PALE VIOLET RED 2');RGB = (/238,121,159/)
CASE ('PALE VIOLET RED 3');RGB = (/205,104,137/)
CASE ('PALE VIOLET RED 4');RGB = (/139,71,93/)
CASE ('PAPAYA WHIP');RGB = (/255,239,213/)
CASE ('PEACH PUFF');RGB = (/255,218,185/)
CASE ('PEACH PUFF 1');RGB = (/238,203,173/)
CASE ('PEACH PUFF 2');RGB = (/205,175,149/)
CASE ('PEACH PUFF 3');RGB = (/139,119,101/)
CASE ('PEACOCK');RGB = (/51,161,201/)
CASE ('PINK');RGB = (/255,192,203/)
CASE ('PINK 1');RGB = (/255,181,197/)
CASE ('PINK 2');RGB = (/238,169,184/)
CASE ('PINK 3');RGB = (/205,145,158/)
CASE ('PINK 4');RGB = (/139,99,108/)
CASE ('PLUM');RGB = (/221,160,221/)
CASE ('PLUM 1');RGB = (/255,187,255/)
CASE ('PLUM 2');RGB = (/238,174,238/)
CASE ('PLUM 3');RGB = (/205,150,205/)
CASE ('PLUM 4');RGB = (/139,102,139/)
CASE ('POWDER BLUE');RGB = (/176,224,230/)
CASE ('PURPLE');RGB = (/128,0,128/)
CASE ('PURPLE 1');RGB = (/155,48,255/)
CASE ('PURPLE 2');RGB = (/145,44,238/)
CASE ('PURPLE 3');RGB = (/125,38,205/)
CASE ('PURPLE 4');RGB = (/85,26,139/)
CASE ('RASPBERRY');RGB = (/135,38,87/)
CASE ('RAW SIENNA');RGB = (/199,97,20/)
CASE ('RED');RGB = (/255,0,0/)
CASE ('RED 1');RGB = (/238,0,0/)
CASE ('RED 2');RGB = (/205,0,0/)
CASE ('RED 3');RGB = (/139,0,0/)
CASE ('ROSY BROWN');RGB = (/188,143,143/)
CASE ('ROSY BROWN 1');RGB = (/255,193,193/)
CASE ('ROSY BROWN 2');RGB = (/238,180,180/)
CASE ('ROSY BROWN 3');RGB = (/205,155,155/)
CASE ('ROSY BROWN 4');RGB = (/139,105,105/)
CASE ('ROYAL BLUE');RGB = (/65,105,225/)
CASE ('ROYAL BLUE 1');RGB = (/72,118,255/)
CASE ('ROYAL BLUE 2');RGB = (/67,110,238/)
CASE ('ROYAL BLUE 3');RGB = (/58,95,205/)
CASE ('ROYAL BLUE 4');RGB = (/39,64,139/)
CASE ('SALMON');RGB = (/250,128,114/)
CASE ('SALMON 1');RGB = (/255,140,105/)
CASE ('SALMON 2');RGB = (/238,130,98/)
CASE ('SALMON 3');RGB = (/205,112,84/)
CASE ('SALMON 4');RGB = (/139,76,57/)
CASE ('SANDY BROWN');RGB = (/244,164,96/)
CASE ('SAP GREEN');RGB = (/48,128,20/)
CASE ('SEA GREEN');RGB = (/84,255,159/)
CASE ('SEA GREEN 1');RGB = (/78,238,148/)
CASE ('SEA GREEN 2');RGB = (/67,205,128/)
CASE ('SEA GREEN 3');RGB = (/46,139,87/)
CASE ('SEASHELL');RGB = (/255,245,238/)
CASE ('SEASHELL 1');RGB = (/238,229,222/)
CASE ('SEASHELL 2');RGB = (/205,197,191/)
CASE ('SEASHELL 3');RGB = (/139,134,130/)
CASE ('SEPIA');RGB = (/94,38,18/)
CASE ('SIENNA');RGB = (/160,82,45/)
CASE ('SIENNA 1');RGB = (/255,130,71/)
CASE ('SIENNA 2');RGB = (/238,121,66/)
CASE ('SIENNA 3');RGB = (/205,104,57/)
CASE ('SIENNA 4');RGB = (/139,71,38/)
CASE ('SILVER');RGB = (/192,192,192/)
CASE ('SKY BLUE');RGB = (/135,206,235/)
CASE ('SKY BLUE 1');RGB = (/135,206,255/)
CASE ('SKY BLUE 2');RGB = (/126,192,238/)
CASE ('SKY BLUE 3');RGB = (/108,166,205/)
CASE ('SKY BLUE 4');RGB = (/74,112,139/)
CASE ('SLATE BLUE');RGB = (/106,90,205/)
CASE ('SLATE BLUE 1');RGB = (/131,111,255/)
CASE ('SLATE BLUE 2');RGB = (/122,103,238/)
CASE ('SLATE BLUE 3');RGB = (/105,89,205/)
CASE ('SLATE BLUE 4');RGB = (/71,60,139/)
CASE ('SLATE GRAY');RGB = (/112,128,144/)
CASE ('SLATE GRAY 1');RGB = (/198,226,255/)
CASE ('SLATE GRAY 2');RGB = (/185,211,238/)
CASE ('SLATE GRAY 3');RGB = (/159,182,205/)
CASE ('SLATE GRAY 4');RGB = (/108,123,139/)
CASE ('SNOW');RGB = (/255,250,250/)
CASE ('SNOW 1');RGB = (/238,233,233/)
CASE ('SNOW 2');RGB = (/205,201,201/)
CASE ('SNOW 3');RGB = (/139,137,137/)
CASE ('SPRING GREEN');RGB = (/0,255,127/)
CASE ('SPRING GREEN 1');RGB = (/0,238,118/)
CASE ('SPRING GREEN 2');RGB = (/0,205,102/)
CASE ('SPRING GREEN 3');RGB = (/0,139,69/)
CASE ('STEEL BLUE');RGB = (/70,130,180/)
CASE ('STEEL BLUE 1');RGB = (/99,184,255/)
CASE ('STEEL BLUE 2');RGB = (/92,172,238/)
CASE ('STEEL BLUE 3');RGB = (/79,148,205/)
CASE ('STEEL BLUE 4');RGB = (/54,100,139/)
CASE ('TAN');RGB = (/210,180,140/)
CASE ('TAN 1');RGB = (/255,165,79/)
CASE ('TAN 2');RGB = (/238,154,73/)
CASE ('TAN 3');RGB = (/205,133,63/)
CASE ('TAN 4');RGB = (/139,90,43/)
CASE ('TEAL');RGB = (/0,128,128/)
CASE ('THISTLE');RGB = (/216,191,216/)
CASE ('THISTLE 1');RGB = (/255,225,255/)
CASE ('THISTLE 2');RGB = (/238,210,238/)
CASE ('THISTLE 3');RGB = (/205,181,205/)
CASE ('THISTLE 4');RGB = (/139,123,139/)
CASE ('TOMATO');RGB = (/255,99,71/)
CASE ('TOMATO 1');RGB = (/238,92,66/)
CASE ('TOMATO 2');RGB = (/205,79,57/)
CASE ('TOMATO 3');RGB = (/139,54,38/)
CASE ('TURQUOISE');RGB = (/64,224,208/)
CASE ('TURQUOISE 1');RGB = (/0,245,255/)
CASE ('TURQUOISE 2');RGB = (/0,229,238/)
CASE ('TURQUOISE 3');RGB = (/0,197,205/)
CASE ('TURQUOISE 4');RGB = (/0,134,139/)
CASE ('TURQUOISE BLUE');RGB = (/0,199,140/)
CASE ('VIOLET');RGB = (/238,130,238/)
CASE ('VIOLET RED');RGB = (/208,32,144/)
CASE ('VIOLET RED 1');RGB = (/255,62,150/)
CASE ('VIOLET RED 2');RGB = (/238,58,140/)
CASE ('VIOLET RED 3');RGB = (/205,50,120/)
CASE ('VIOLET RED 4');RGB = (/139,34,82/)
CASE ('WARM GREY');RGB = (/128,128,105/)
CASE ('WHEAT');RGB = (/245,222,179/)
CASE ('WHEAT 1');RGB = (/255,231,186/)
CASE ('WHEAT 2');RGB = (/238,216,174/)
CASE ('WHEAT 3');RGB = (/205,186,150/)
CASE ('WHEAT 4');RGB = (/139,126,102/)
CASE ('WHITE');RGB = (/255,255,255/)
CASE ('WHITE SMOKE');RGB = (/245,245,245/)
CASE ('YELLOW');RGB = (/255,255,0/)
CASE ('YELLOW 1');RGB = (/238,238,0/)
CASE ('YELLOW 2');RGB = (/205,205,0/)
CASE ('YELLOW 3');RGB = (/139,139,0/)

CASE DEFAULT
  RGB = (/0,0,0/)
END SELECT

END SUBROUTINE COLOR2RGB







