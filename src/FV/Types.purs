module FV.Types
  ( MCtruth (..)
  , Prong (..)
  , Chi2
  , Jaco (..)
  , VHMeas (..), vertex, helices, hFilter
  , XMeas (..), vBlowup
  , HMeas (..)
  , QMeas (..), fromHMeas
  , PMeas (..), fromQMeas, invMass
  , MMeas (..)
  , M3 (..), V3 (..)
  , M5 (..), V5 (..)
  , typeShow
  ) where

import Prelude
import Data.Array ( length, (!!), unsafeIndex, drop, zip, foldl )
import Data.Foldable ( fold )
import Data.Monoid ( class Monoid, mempty )
import Data.Tuple ( Tuple (..) )
import Data.Array.Partial ( head )
import Data.List ( List (..), (:) )
import Partial.Unsafe ( unsafePartial )
import Data.Int (round, toNumber)
import Math ( sqrt, abs, pi, sin, cos )

import Stuff
import Data.Matrix  ( M, nrows, ncols, values, fromList2, fromList, fromLists
                    , diagonal, identity, zero_
                    , Matrix (..)
                    , getDiag, toList, subm, subm2
                    , sw, tr, scaleDiag
                    , elementwiseUnsafePlus, elementwiseUnsafeMinus, multStd )

newtype Dim3 = Dim3 Int
newtype Dim5 = Dim5 Int
newtype MM a = MM (Matrix Number)

instance semiringMM3 :: Semiring (MM Dim3) where
  add (MM m1) (MM m2) = MM $ elementwiseUnsafePlus m1 m2
  zero = MM $ zero_ 3 3
  mul (MM m1) (MM m2) = MM $ multStd m1 m2
  one = MM $ identity 3
instance ringMM3 :: Ring (MM Dim3) where
  sub (MM m1) (MM m2) = MM $ elementwiseUnsafeMinus m1 m2
instance showMM3 :: Show (MM Dim3) where
  show (MM m) = "Show (MM Dim3) " <> show m

instance semiringMM5 :: Semiring (MM Dim5) where
  add (MM m1) (MM m2) = MM $ elementwiseUnsafePlus m1 m2
  zero = MM $ zero_ 5 5
  mul (MM m1) (MM m2) = MM $ multStd m1 m2
  one = MM $ identity 5
instance ringMM5 :: Ring (MM Dim5) where
  sub (MM m1) (MM m2) = MM $ elementwiseUnsafeMinus m1 m2
instance showMM5 :: Show (MM Dim5) where
  show (MM m) = "Show (MM Dim5) " <> show m

newtype MD = MakeMD {m3 :: (MM Dim3), m5 :: MM Dim5}
instance showMD :: Show MD where
  show (MakeMD {m3, m5}) = "Show MD, m3=" <> show m3 <> "\nm5=" <> show m5  

typeShow = "testShow: " <> show md where
  mm3 :: MM Dim3
  mm3 = MM $ fromList2 3 3 [1.0,2.0,3.0,4.0,5.0,6.0,7.0,8.0,9.0]
  m5 :: MM Dim5
  m5 = one
  md = MakeMD {m3: (mm3+mm3)*mm3, m5}

-----------------------------------------------
newtype V3 = V3 M
newtype M3 = M3 M
newtype V5 = V5 M
newtype M5 = M5 M

type Jaco = { aa :: M, bb :: M, h0:: M }
-----------------------------------------------
-- Prong
-- a prong results from a vertex fit of N helices
type Chi2  = Number
data Prong = Prong
          { nProng        :: Int
          , fitVertex     :: XMeas
          , fitMomenta    :: Array QMeas
          , fitChi2s      :: Array Chi2
          , measurements  :: VHMeas
          }
instance showProng :: Show Prong where
  show _ = "Prong!!!!!!!!"
-----------------------------------------------
-- VHMeas
--
newtype VHMeas = VHMeas {
    vertex      :: XMeas
  , helices     :: Array HMeas
                     }
vertex :: VHMeas -> XMeas
vertex (VHMeas {vertex}) = vertex
helices :: VHMeas -> Array HMeas
helices (VHMeas {helices}) = helices
{-- instance semigroupHMeas :: Semigroup VHMeas where --}
{--   append (VHMeas v hs) (VHMeas _ hs') = VHMeas v ( hs ++ hs' ) --}
{--   mempty = VHMeas (XMeas (Matrix.zero 3 1) (Matrix.zero 3 3)) [] --}

instance showVHMeas :: Show VHMeas where
  show (VHMeas {vertex, helices}) = "VHMeas w/ " <> show (length helices)
                                    <> " tracks. " <> show vertex

vBlowup :: Number -> VHMeas -> VHMeas
{-- vBlowup scale vm = over vertexLens (blowup scale) vm where --}
vBlowup scale (VHMeas {vertex: v, helices: hs}) = VHMeas {vertex: (blowup scale v), helices: hs} where
  blowup :: Number -> XMeas -> XMeas -- blow up diag of cov matrix
  blowup s (XMeas v (M3 cv)) = XMeas v (M3 cv') where
    cv' = scaleDiag s cv

hFilter :: Array Int -> VHMeas -> VHMeas
hFilter is (VHMeas {vertex, helices}) = VHMeas {vertex, helices: (iflt is helices)}

hRemove :: Int -> VHMeas -> VHMeas
hRemove indx (VHMeas {vertex, helices}) = VHMeas {vertex, helices:(irem indx helices)}

-----------------------------------------------
-- MCtruth
--
data MCtruth = MCtruth {
    pu_zpositions :: Array Number
                       }
instance showMCtruth :: Show MCtruth where
  show (MCtruth {pu_zpositions}) = "MCtruth w/" <> show (length pu_zpositions)
                                                <> " PU z positions."


-----------------------------------------------
-- HMeas
-- 5-vector and covariance matrix for helix measurement
--
data HMeas = HMeas V5 M5 Number
instance showHMeas :: Show HMeas where
  show (HMeas (V5 h) (M5 ch) w0) = s' where
    sh = map sqrt $ getDiag ch
    hs = toList h
    s00 = to5fix x <> " +-" <> to5fix dx where
      x  = unsafePartial $ head hs
      dx = unsafePartial $ head sh
    s' = foldl f s00 (drop 1 $ zip hs sh) where
      f s (Tuple x dx)  = s <> to3fix x <> " +-" <> to3fix dx

-----------------------------------------------
-- QMeas
-- 3-vector and covariance matrix for momentum measurement
--
mπ :: Number
mπ = 0.1395675E0
data QMeas = QMeas M M Number
instance showAMeas :: Show QMeas where
  show = showQMeas
-- print QMeas as a 4-momentum vector with errors, use pt and pz
showQMeas :: QMeas -> String
showQMeas (QMeas q cq w2pt) = s' where
  f :: String -> (Tuple Number Number) -> String
  f s (Tuple x dx)  = s <> to3fix x <> " +-" <> to3fix dx
  m          = mπ
  wp         = w2pt
  qs :: Array Number
  qs         = toList q
  w          = uidx qs 0
  tl         = uidx qs 1
  psi0       = uidx qs 2
  pt         = wp / abs w
  pz         = pt*tl
  psi        = psi0*180.0/pi
  e          = sqrt(pt*pt  + pz*pz + m*m)
  jj         = fromLists $
              [-wp/w/w, -wp/w/w*tl,0.0, -(pz*pz + pt*pt)/w/e]
              : [0.0, wp/w, 0.0, pt*pt*tl/e]
              : [0.0, 0.0, 1.0, 0.0]
              : Nil
  cq'        = (tr jj) * cq* jj
  p'         = [pt, pz, psi, e]
  dp         = map sqrt $ getDiag cq'
  d1         = uidx dp 0
  d2         = uidx dp 1
  d3         = uidx dp 2
  d4         = uidx dp 3
  dp'        = [d1, d2, d3*180.0/pi, d4]
  s'         = (foldl f "" $ zip p' dp' ) <> " GeV"

fromHMeas :: HMeas -> QMeas -- just drop the d0, z0 part... fix!!!!
fromHMeas (HMeas (V5 h) (M5 ch) w2pt) = QMeas q cq w2pt where
  q = subm 3 h
  cq = subm2 3 ch

h2p :: HMeas -> PMeas
h2p = fromQMeas <<< fromHMeas

-----------------------------------------------
-- PMeas
-- 4-vector and coavariance matrix for momentum px,py,pz and energy
--
data PMeas = PMeas M M
instance semigroupPMeas :: Semigroup PMeas where
  append (PMeas p1 cp1) (PMeas p2 cp2) = PMeas (p1+p2) (cp1 + cp2)
instance monoidPMeas :: Monoid PMeas where
  mempty = PMeas (zero_ 4 1) (zero_ 4 4)
instance showPMeasInst :: Show PMeas where
  show = showPMeas
-- print PMeas as a 4-momentum vector px,py,pz,E with errors
showPMeas :: PMeas -> String
showPMeas (PMeas p cp) = s' where
  s' = "PMeas -----------"
  {-- sp         = Data.Vector.map sqrt $ Data.Matrix.getDiag cp --}
  {-- f s (x, dx)  = s ++ printf "%8.3f +- %8.3f" (x::Double) (dx::Double) -- \xc2b1 ±±±±± --}
  {-- s' = (foldl f "" $ Data.Vector.zip (Data.Matrix.getCol 1 p) sp) ++ " GeV" --}

invMass :: Array PMeas -> MMeas
invMass ps = pmass <<< fold $ ps

pmass :: PMeas -> MMeas
pmass (PMeas p cp) = mm  where
  ps    = toList p
  px    = uidx ps 0
  py    = uidx ps 1
  pz    = uidx ps 2
  e     = uidx ps 3
  cps   = toList cp
  c11   = uidx cps 0
  c12   = uidx cps 1
  c13   = uidx cps 2
  c14   = uidx cps 3
  c22   = uidx cps 5
  c23   = uidx cps 6
  c24   = uidx cps 7
  c33   = uidx cps 10
  c34   = uidx cps 11
  c44   = uidx cps 15
  m     = sqrt $ max (e*e-px*px-py*py-pz*pz) 0.0
  sigm0 = px*c11*px + py*c22*py + pz*c33*pz + e*c44*e +
            2.0*(px*(c12*py + c13*pz - c14*e)
               + py*(c23*pz - c24*e)
               - pz*c34*e)
  dm    =  sqrt ( max sigm0 0.0 ) / m
  mm    = MMeas {m, dm}

fromQMeas :: QMeas -> PMeas
fromQMeas (QMeas q0 cq0 w2pt) = PMeas p0 cp0 where
  m = mπ
  q0s = toList q0
  w    = uidx q0s 0
  tl   = uidx q0s 1
  psi0 = uidx q0s 2
  sph  = sin psi0
  cph  = cos psi0
  pt   = w2pt / abs w
  px   = pt * cph
  py   = pt * sph
  pz   = pt * tl
  sqr  = \x -> x*x
  e    = sqrt(px*px + py*py + pz*pz + m*m)
  ps   = w2pt / w
  dpdk = ps*ps/w2pt
  cq0s = toList cq0
  c11  = uidx cq0s 0
  c12  = uidx cq0s 1
  c13  = uidx cq0s 2
  c22  = uidx cq0s 4
  c23  = uidx cq0s 5
  c33  = uidx cq0s 8
  xy   = 2.0*ps*dpdk*cph*sph*c13
  sxx  = sqr (dpdk*cph) * c11 + sqr (ps*sph) * c33 + xy
  sxy  = cph*sph*(dpdk*dpdk*c11 - ps*ps*c33) +
           ps*dpdk*(sph*sph-cph*cph)*c13
  syy  = sqr (dpdk*sph) * c11 + sqr (ps*cph) * c33 - xy
  sxz  = dpdk*dpdk*cph*tl*c11 -
           ps*dpdk*(cph*c12-sph*tl*c13) -
           ps*ps*sph*c23
  syz  = dpdk*dpdk*sph*tl*c11 -
           ps*dpdk*(sph*c12 + cph*tl*c13) +
           ps*ps*cph*c23
  szz  = sqr (dpdk*tl) * c11 + ps*ps*c22 -
           2.0*ps*dpdk*tl*c12
  sxe  = (px*sxx + py*sxy + pz*sxz)/e
  sye  = (px*sxy + py*syy + pz*syz)/e
  sze  = (px*sxz + py*syz + pz*szz)/e
  see  = (px*px*sxx + py*py*syy + pz*pz*szz +
         2.0*(px*(py*sxy + pz*sxz) + py*pz*syz))/e/e

  p0   = fromList 4 [px,py,pz,e]
  cp0  = fromList2 4 4 [ sxx, sxy, sxz, sxe,
                         sxy, syy, syz, sye,
                         sxz, syz, szz, sze,
                         sxe, sye, sze, see]

-----------------------------------------------
-- MMeas
-- scalar mass and error calculated from PMeas covariance matrices
--
data MMeas = MMeas
            { m :: Number
            , dm :: Number
            }
instance showMMeas :: Show MMeas where
  show (MMeas {m, dm}) = " " <> to1fix (m*1000.0) <> " +-" <> to1fix (dm*1000.0) <> " MeV"

-----------------------------------------------
-- XMeas
-- 3-vector and covariance matrix for position/vertex measurement
--
data XMeas = XMeas V3 M3
instance showXMeasinst :: Show XMeas where
  show = showXMeas
-- return a string showing vertex position vector with errors
showXMeas :: XMeas -> String
showXMeas (XMeas (V3 v) (M3 cv)) = s' where
  vv         = toList v
  x          = unsafePartial $ unsafeIndex vv 0
  y          = unsafePartial $ unsafeIndex vv 1
  z          = unsafePartial $ unsafeIndex vv 2
  s2v        = map sqrt $ getDiag cv
  dx         = unsafePartial $ unsafeIndex s2v 0
  dy         = unsafePartial $ unsafeIndex s2v 1
  dz         = unsafePartial $ unsafeIndex s2v 2
  f :: Number -> Number -> String -> String
  f x dx s  = s <> to3fix x <>  " +-" <> to3fix dx
  s' = (f z dz) <<< (f y dy) <<< (f x dx) $
    "(r,z) =" <> "(" <> to3fix (sqrt (x*x + y*y))
              <> ", " <> to3fix z <> "), x y z ="
