-- | Alegbraic data types for OSC datum and packets.
module Sound.OpenSoundControl.Type where

import qualified Data.ByteString.Lazy as B
import Data.Maybe
import Data.Word
import Sound.OpenSoundControl.Time

-- | The basic elements of OSC messages.
data Datum = Int Int
           | Float Double
           | Double Double
           | String String
           | Blob B.ByteString
           | TimeStamp Time
           | Midi (Word8,Word8,Word8,Word8)
             deriving (Eq,Read,Show)

-- | OSC address pattern.
type Address_Pattern = String

-- | An OSC message.
data Message = Message Address_Pattern [Datum]
               deriving (Eq,Read,Show)

-- | An OSC bundle.
data Bundle = Bundle Time [Message]
              deriving (Eq,Read,Show)

-- | An OSC 'Packet' is either a 'Message' or a 'Bundle'.
data Packet = P_Message Message | P_Bundle Bundle
              deriving (Eq,Read,Show)

-- | OSC 'Bundle's can be ordered (time ascending).
instance Ord Bundle where
    compare (Bundle a _) (Bundle b _) = compare a b

-- | 'Bundle' constructor. It is an 'error' if the 'Message' list is
-- empty.
bundle :: Time -> [Message] -> Bundle
bundle t xs =
    case xs of
      [] -> error "bundle: empty?"
      _ -> Bundle t xs

-- | 'Message' constructor.  It is an 'error' if the 'Address_Pattern'
-- doesn't conform to the OSC specification.
message :: Address_Pattern -> [Datum] -> Message
message a xs =
    case a of
      '/':_ -> Message a xs
      _ -> error "message: ill-formed address pattern"

-- * Datum

-- | Single character identifier of an OSC datum.
datum_tag :: Datum -> Char
datum_tag dt =
    case dt of
      Int _ -> 'i'
      Float _ -> 'f'
      Double _ -> 'd'
      String _ -> 's'
      Blob _ -> 'b'
      TimeStamp _ -> 't'
      Midi _ -> 'm'

-- | 'Datum' as real number if 'Double', 'Float' or 'Int', else 'Nothing'.
--
-- > map datum_real [Int 5,Float 5,String "5"] == [Just 5,Just 5,Nothing]
datum_real :: Datum -> Maybe Double
datum_real d =
    case d of
      Double n -> Just n
      Float n -> Just n
      Int n -> Just (fromIntegral n)
      _ -> Nothing

-- | A 'fromJust' variant of 'datum_real'.
--
-- > map datum_real_err [Int 5,Float 5] == [5,5]
datum_real_err :: Datum -> Double
datum_real_err = fromJust . datum_real

-- | 'Datum' as integral number if 'Double', 'Float' or 'Int', else
-- 'Nothing'.
--
-- > map datum_int [Int 5,Float 5.5,String "5"] == [Just 5,Just 5,Nothing]
datum_int :: Integral i => Datum -> Maybe i
datum_int d =
    case d of
      Int x -> Just (fromIntegral x)
      Float x -> Just (floor x)
      Double x -> Just (floor x)
      _ -> Nothing

-- | A 'fromJust' variant of 'datum_int'.
--
-- > map datum_int_err [Int 5,Float 5.5] == [5,5]
datum_int_err :: Integral i => Datum -> i
datum_int_err = fromJust . datum_int

-- | 'Datum' as 'String' if 'String' or 'Blob', else 'Nothing'.
--
-- > map datum_string [String "5",Blob (B.pack [53])] == [Just "5",Just "5"]
datum_string :: Datum -> Maybe String
datum_string d =
    case d of
      Blob s -> Just (map (toEnum . fromIntegral) (B.unpack s))
      String s -> Just s
      _ -> Nothing

-- | A 'fromJust' variant of 'datum_string'.
--
-- > map datum_string_err [String "5",Blob (B.pack [53])] == ["5","5"]
datum_string_err :: Datum -> String
datum_string_err = fromJust . datum_string

-- | Does 'Message' have the specified 'Address_Pattern'.
message_has_address :: Address_Pattern -> Message -> Bool
message_has_address x (Message y _) = x == y

-- | Does the first 'Message' at 'Bundle' have the specified
-- 'Address_Pattern'.
bundle_has_address :: Address_Pattern -> Bundle -> Bool
bundle_has_address x b =
    case b of
      Bundle _ (m:_) -> message_has_address x m
      _ -> error "bundle_has_address: empty bundle?"

-- | Does 'Packet' have the specified 'Address_Pattern'.
packet_has_address :: Address_Pattern -> Packet -> Bool
packet_has_address x p =
    case p of
      P_Message m -> message_has_address x m
      P_Bundle b -> bundle_has_address x b

-- | If 'Packet' is a 'Message' or a 'Bundle' with one element, return
-- the 'Message', else 'Nothing'.
packet_to_messages :: Packet -> [Message]
packet_to_messages p =
    case p of
      P_Message m -> [m]
      P_Bundle (Bundle _ m) -> m

-- | 'Nothing' if packet has does not have singular 'Message'.
packet_to_message :: Packet -> Maybe Message
packet_to_message p =
    case packet_to_messages p of
      [m] -> Just m
      _ -> Nothing

-- | Variant of 'packet_to_messages' discarding all but initial message.
packet_to_message_discard :: Packet -> Message
packet_to_message_discard p =
    case packet_to_messages p of
      m:_ -> m
      _ -> error "packet_to_message_discard: empty bundle?"

-- | If 'Packet' is a 'Message' add 'immediately' timestamp, else 'id'.
packet_to_bundle :: Packet -> Bundle
packet_to_bundle p =
    case p of
      P_Message m -> Bundle immediately [m]
      P_Bundle b -> b

-- | Variant of 'either' for 'Packet'.
at_packet :: (Message -> a) -> (Bundle -> a) -> Packet -> a
at_packet f g p =
    case p of
      P_Message m -> f m
      P_Bundle b -> g b
