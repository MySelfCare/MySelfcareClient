module Components.Router where


import Data.Routing.Routes as R
import Data.Routing.Routes.Journals as RJ
import Data.Routing.Routes.Sessions as RS
import Components.Intro as Intro
import Components.Journals as Journals
import Components.NotFound as NotFound
import Components.Resources as Resources
import Components.Sessions as Sessions
import Data.Const (Const)
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (Aff, launchAff)
import Effect.Aff.Class (class MonadAff)
import Halogen as H
import Halogen.Component.ChildPath (ChildPath, cpL, cpR, (:>))
import Halogen.Data.Prism (type (<\/>), type (\/))
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Model (Model, Session)
import Prelude (type (~>), Unit, Void, const, pure, unit, (<<<), bind, ($), discard, map)
import Routing.Hash (matches)

data Input a
  = Goto R.Routes a
  | UpdateSession Session a

type ChildQuery
  = Intro.Query
  <\/> Resources.Query
  <\/> Sessions.Query
  <\/> NotFound.Query
  <\/> Journals.Query
  <\/> Const Void

type ChildSlot
  = Intro.Slot
  \/ Resources.Slot
  \/ Sessions.Slot
  \/ NotFound.Slot
  \/ Journals.Slot
  \/ Void


nada  :: forall a b. a -> Maybe b
nada = const Nothing

pathToIntro :: ChildPath Intro.Query ChildQuery Intro.Slot ChildSlot
pathToIntro = cpL

pathToResources :: ChildPath Resources.Query ChildQuery Resources.Slot ChildSlot
pathToResources = cpR :> cpL

pathToSessions :: ChildPath Sessions.Query ChildQuery Sessions.Slot ChildSlot
pathToSessions = cpR :> cpR :> cpL

pathToNotFound :: ChildPath NotFound.Query ChildQuery NotFound.Slot ChildSlot
pathToNotFound = cpR :> cpR :> cpR :> cpL

pathToJournals :: ChildPath Journals.Query ChildQuery Journals.Slot ChildSlot
pathToJournals =  cpR :> cpR :> cpR :> cpR :> cpL

component
  :: forall m
  . MonadAff m
  => Model
  -> H.Component HH.HTML Input Unit Void m
component initialModel = H.parentComponent
  { initialState: const initialModel
  , render
  , eval
  , receiver: const Nothing
  }
  where
    render :: Model -> H.ParentHTML Input ChildQuery ChildSlot m
    render model = HH.div_ [navMenu, viewPage model model.currentPage] where
      navMenu = case model.session of
        Just session -> sessionedMenu session
        Nothing      -> sessionlessMenu


    sessionlessMenu :: H.ParentHTML Input ChildQuery ChildSlot m
    sessionlessMenu =
      HH.nav_
        [ HH.ul_ (map link [R.Intro, R.Resources, R.Sessions RS.Login])
        ]

    sessionedMenu :: Session -> H.ParentHTML Input ChildQuery ChildSlot m
    sessionedMenu session =
      HH.nav_
        [ HH.ul_ (map link [R.Intro, R.Resources, R.Journals $ RJ.Edit Nothing])
        ]

    link r = HH.li_ [ HH.a [ HP.href $ R.reverseRoute r ] [ HH.text $ R.reverseRoute r ] ]

    viewPage :: Model -> R.Routes -> H.ParentHTML Input ChildQuery ChildSlot m
    viewPage model R.Intro =
      HH.slot'
        pathToIntro
        Intro.Slot
        (Intro.component model.localiseFn)
        unit
        nada
    viewPage model R.Resources =
      HH.slot'
        pathToResources
        Resources.Slot
        (Resources.component model.localiseFn)
        unit
        nada
    viewPage model (R.Sessions r) =
      HH.slot'
        pathToSessions
        Sessions.Slot
        (Sessions.component model.localiseFn)
        (Sessions.RouteContext r)
        mapSessionMessage
    viewPage model R.NotFound =
      HH.slot'
        pathToNotFound
        NotFound.Slot
        (NotFound.component model.localiseFn)
        unit
        nada
    viewPage model (R.Journals r) =
      HH.slot'
        pathToJournals
        Journals.Slot
        (Journals.component model.localiseFn)
        (Journals.JournalsContext { routeContext: r, journalsState: model.journalsState})
        nada

    eval :: Input ~> H.ParentDSL Model Input ChildQuery ChildSlot Void m
    eval (Goto loc next) = do
      H.modify_ (_{ currentPage = loc})
      pure next
    eval (UpdateSession sess next) = do
      H.modify_ (_{ session = Just sess })
      pure next

routeSignal :: H.HalogenIO Input Void Aff -> Effect (Effect Unit)
routeSignal driver = matches R.routes hashChanged
  where
    hashChanged _ newRoute = do
      _ <- launchAff $ driver.query <<< H.action <<< Goto $ newRoute
      pure unit

mapSessionMessage :: Sessions.Message -> Maybe (Input Unit)
mapSessionMessage (Sessions.SessionCreated session) = Just (UpdateSession session unit)