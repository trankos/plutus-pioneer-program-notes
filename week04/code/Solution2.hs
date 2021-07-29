{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

module Week04.Homework where

import Data.Aeson (FromJSON, ToJSON)
import Data.Functor (void)
import Data.Text (Text, unpack)
import GHC.Generics (Generic)
import Ledger
import Ledger.Ada as Ada
import Ledger.Constraints as Constraints
import Plutus.Contract as Contract
import Plutus.Trace.Emulator as Emulator
import Wallet.Emulator.Wallet

data PayParams = PayParams
  { ppRecipient :: PubKeyHash,
    ppLovelace :: Integer
  }
  deriving (Show, Generic, FromJSON, ToJSON)

type PaySchema = Endpoint "pay" PayParams

payContract :: Contract () PaySchema Text ()
payContract = do
  pp <- endpoint @"pay"
  let tx = mustPayToPubKey (ppRecipient pp) $ lovelaceValueOf $ ppLovelace pp
  void $ submitTx tx
  Contract.logInfo @String "Contract submitted"
  payContract

payContractHandleException :: Contract () PaySchema Text ()
payContractHandleException =
  Contract.handleError
    (\err -> Contract.logError $ "Exception: " ++ unpack err)
    payContract

-- A trace that invokes the pay endpoint of payContract on Wallet 1 twice, each time with Wallet 2 as
-- recipient, but with amounts given by the two arguments. There should be a delay of one slot
-- after each endpoint call.
payTrace :: Integer -> Integer -> EmulatorTrace ()
payTrace pay1 pay2 = do
  h <- activateContractWallet (Wallet 1) payContractHandleException

  let pkh2 = pubKeyHash $ walletPubKey $ Wallet 2

  callEndpoint @"pay"
    h
    PayParams
      { ppRecipient = pkh2,
        ppLovelace = pay1
      }
  void $ Emulator.waitNSlots 1
  callEndpoint @"pay"
    h
    PayParams
      { ppRecipient = pkh2,
        ppLovelace = pay2
      }
  void $ Emulator.waitNSlots 1

payTest1 :: IO ()
payTest1 = runEmulatorTraceIO $ payTrace 1000000 2000000 

payTest2 :: IO ()
payTest2 = runEmulatorTraceIO $ payTrace 1000000000 2000000 