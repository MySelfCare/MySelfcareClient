module Data.Routing.Routes.Sessions where

import Data.Routing.Class (class ReverseRoute)

data Sessions
  = Login
  | Register
  | Logout


instance reverseRouteSessions :: ReverseRoute Sessions where
  reverseRoute r = case r of
    Login -> "login"
    Register -> "register"
    Logout -> "logout"


