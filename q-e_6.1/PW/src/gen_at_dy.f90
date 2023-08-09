!
! Copyright (C) 2002-2020 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!-------------------------------------------------------------------------
SUBROUTINE gen_at_dy( ik, u, dwfcat )
   !----------------------------------------------------------------------
   !! This routines calculates the atomic wfc generated by the derivative
   !! (with respect to the q vector) of the spherical harmonic. This quantity
   !! is needed in computing the the internal stress tensor.
   !
   USE kinds,      ONLY: DP
   USE io_global,  ONLY: stdout
   USE constants,  ONLY: tpi, fpi
   USE ions_base,  ONLY: nat, ntyp => nsp, ityp, tau
   USE cell_base,  ONLY: omega, at, bg, tpiba
   USE klist,      ONLY: xk, ngk, igk_k
   USE gvect,      ONLY: mill, eigts1, eigts2, eigts3, g
   USE wvfct,      ONLY: npwx
   USE uspp_param, ONLY: upf, nwfcm
   USE basis,      ONLY : natomwfc
   !
   IMPLICIT NONE
   !
   INTEGER,  INTENT(IN) :: ik
   !! k-point index
   REAL(DP), INTENT(IN) :: u(3)
   !! unit vector
   COMPLEX(DP) :: dwfcat(npwx,natomwfc)
   !! atomic wfc
   !
   ! ... local variables
   !
   INTEGER     :: ig, na, nt, nb, l, lm, m, iig, ipol, iatw, &
                  lmax_wfc, npw
   REAL(DP)    :: arg
   COMPLEX(DP) :: phase, pref
   !
   REAL(DP),    ALLOCATABLE :: q(:), gk(:,:), dylm(:,:), dylm_u(:,:), &
                               chiq(:,:,:)
   COMPLEX(DP), ALLOCATABLE :: sk(:)
   !
   npw = ngk(ik)
   ! calculate max angular momentum required in wavefunctions
   lmax_wfc = 0
   do nt = 1, ntyp
      lmax_wfc = MAX ( lmax_wfc, MAXVAL (upf(nt)%lchi(1:upf(nt)%nwfc) ) )
   enddo
   !
   ALLOCATE( q(npw), gk(3,npw), chiq(npw,nwfcm,ntyp) )
   !
   dwfcat(:,:) = (0.d0,0.d0)
   DO ig = 1,npw
      iig = igk_k(ig,ik)
      gk(1, ig) = xk(1, ik) + g(1,iig)
      gk(2, ig) = xk(2, ik) + g(2,iig)
      gk(3, ig) = xk(3, ik) + g(3,iig)
      q(ig) = gk(1, ig)**2 +  gk(2, ig)**2 + gk(3, ig)**2
   ENDDO
   !
   ALLOCATE( dylm_u(npw,(lmax_wfc+1)**2) )
   ALLOCATE( dylm(npw,(lmax_wfc+1)**2)   )
   dylm_u(:,:) = 0.d0
   !
   !  Derivatives of spherical harmonics
   !
   DO ipol=1,3
      CALL dylmr2( (lmax_wfc+1)**2, npw, gk, q, dylm, ipol )
      CALL daxpy( npw*(lmax_wfc+1)**2, u(ipol), dylm, 1, dylm_u, 1 )
   ENDDO
   !
   DEALLOCATE( dylm )
   !
   q(:) = SQRT(q(:))*tpiba
   CALL interp_atwfc ( npw, q, nwfcm, chiq )
   !
   ALLOCATE( sk(npw) )
   !
   iatw=0
   DO na = 1, nat
      nt = ityp(na)
      arg = ( xk(1,ik)*tau(1,na) + &
              xk(2,ik)*tau(2,na) + &
              xk(3,ik)*tau(3,na) )*tpi
      phase = CMPLX( COS(arg), -SIN(arg), KIND=DP )
      DO ig =1, npw
         iig = igk_k(ig,ik)
         sk(ig) = eigts1(mill(1,iig),na) * &
                  eigts2(mill(2,iig),na) * &
                  eigts3(mill(3,iig),na) * phase
      ENDDO
      DO nb = 1,upf(nt)%nwfc
         ! Note: here we put ">=" to be consistent with "atomic_wfc"/"n_atom_wfc"
         IF ( upf(nt)%oc(nb) >= 0.d0 ) THEN
            l  = upf(nt)%lchi(nb)
            pref = (0.d0,1.d0)**l
            DO m = 1, 2*l+1
               lm = l*l+m
               iatw = iatw+1
               DO ig = 1, npw
                  dwfcat(ig,iatw) = chiq(ig,nb,nt) * sk(ig) * &
                                    dylm_u(ig,lm) * pref / tpiba
               ENDDO
            ENDDO
         ENDIF
      ENDDO
   ENDDO
   !
   IF (iatw /= natomwfc) THEN
      WRITE( stdout,*) 'iatw =',iatw,'natomwfc =',natomwfc
      CALL errore( 'gen_at_dy','unexpected error', 1 )
   ENDIF
   !
   DEALLOCATE( sk          )
   DEALLOCATE( dylm_u      )
   DEALLOCATE( q, gk, chiq )
   !
   RETURN
   !
END SUBROUTINE gen_at_dy