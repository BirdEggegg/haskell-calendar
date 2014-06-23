import Control.Applicative
import Data.Time.Format
import Data.Time.LocalTime
import System.Locale

import Configuration

data Weekday = Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday
               deriving (Show, Eq, Enum, Read)

dayNext :: Weekday -> Weekday
dayNext Sunday = Monday
dayNext d = succ d

stringToWd :: String -> Weekday
stringToWd s | s == "0" = Sunday
             | s == "1" = Monday
             | s == "2" = Tuesday
             | s == "3" = Wednesday
             | s == "4" = Thursday
             | s == "5" = Friday
             | s == "6" = Saturday
             | otherwise = error $ "stringToWd: only 0 - 6 are valid weekday codes, given was " ++ s


-- m a = m (s -> (s,a))
newtype CalendarMonad a = CalendarMonad (Weekday -> (Weekday, a))

instance Functor CalendarMonad where
    fmap f (CalendarMonad transform)
        = CalendarMonad $ \state0 -> let (state1, value0) = transform state0
                                         value1 = f value0
                                     in (state1, value1)

instance Applicative CalendarMonad where
    pure a = CalendarMonad (\state -> (state, a))
    CalendarMonad transform0 <*> CalendarMonad transform1
        = CalendarMonad $ \state0 -> let (state1, f) = transform0 state0
                                         (state2, value1) = transform1 state1
                                         value2 = f value1
                                     in (state2, value2)

instance Monad CalendarMonad where
    return a = CalendarMonad $ \x -> (x,a)
    (CalendarMonad transform0) >>= ftransform
        = CalendarMonad $ \state0 -> let (state1, value1) = transform0 state0
                                         CalendarMonad transform1 = ftransform value1
                                         (state2, value2) = transform1 state1
                                     in (state2, value2)

getWorkDayTable :: (Weekday -> Bool) -> CalendarMonad (Weekday,Bool)
getWorkDayTable workDay = CalendarMonad $ \day -> (dayNext day, (day, workDay day))

workDayList :: IO [Weekday]
workDayList = let weekdayString :: IO String
                  weekdayString = fmap (maybe "" id) $ getConfigOption "default.workdays"
              in fmap ((map read) . words) weekdayString
         

listNextDays :: Weekday -> Int -> (Weekday -> Bool) -> [(Weekday, Bool)]
listNextDays weekday n procedure = let nd 0 accu = return accu
                                       nd m accu = do
                                         wd <- getWorkDayTable procedure
                                         nd (m-1) (wd:accu)
                                       CalendarMonad runIt = nd n []
                                   in reverse $ snd $ (runIt weekday)

makeTable :: [(Weekday, Bool)] -> String
makeTable dates = let makeLine :: (Weekday, Bool) -> String
                      makeLine (wd,bool) = "| " ++ show wd ++ "\t | " ++ (workdayToString bool) ++ " |"
                      workdayToString :: Bool -> String
                      workdayToString True  = "Arbeit"
                      workdayToString False = "  frei"
                  in unlines $ map makeLine dates

localTimeToWeekday :: LocalTime -> Weekday
localTimeToWeekday lt = let formatString = "%w"
                        in stringToWd $ formatTime defaultTimeLocale formatString lt

getCurrentTime :: IO LocalTime
getCurrentTime = fmap zonedTimeToLocalTime getZonedTime

main :: IO ()
main = do
  wd <- fmap localTimeToWeekday getCurrentTime
  workdays <- workDayList
  putStr $ makeTable $ listNextDays wd 5 (\x -> elem x workdays)
