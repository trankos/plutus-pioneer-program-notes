Clase 06
- [Video](https://www.youtube.com/watch?v=24SHPHEc3zo)
- [Notas](https://docs.plutus-community.com/docs/lectures/Lecture6.html)

# Introducción
- Vamos a analizar un caso de estudio que comprenda el uso de _oracles_ (_oráculos_). Un _oracle_ (_oráculo_) es una fuente de datos de confianza que puede utilizarse como entrada para realizar transacciones.

# Oracle 
- Para poder utilizar una fuente de información externa en una transacción en la _Blockchain_, la aproximación más sencilla es que esta información sea un UTXo. Hay otras formas más sofisticadas, pero para el propósito que nos ocupa, es suficiente.
- Por tanto, los datos que genera el _oracle_ se encapsulan en una UTXo que tienen como _dirección_ el _oracle_. El _Datum_ de la UTXo contrendrá la información.
    - En este caso, se trata de información en tiempo real de la cotización de ADA/USD.
- Primer problema: Un validación en un script _on chain_, solo se ejecuta cuando se _consume_ dicho UTXo. No se puede impedir la generación de UTXo arbitrarias desde el _oracle_.
- Para identificar de forma única esta UTXo, se utiliza un NFT, que se sabemos que es único. O sea, tenemos una UTXo tal que:
    - Proviene de un _oráculo_ determinado
    - Es única: Tiene un NFT asociada
    - Contiene un dato de confianza, el que sea (esto nos lo creeemos por el momento)

- En general, un _oráculo_ no sabe como van a utilizarse sus datos (entiendo que los ofrecerá en un formato dado, definido como  una API)

# Contrato
- Para nuestro caso, el contrato que es un servicio de _Swap_, donde de puede cambiar ADA por USD, a la cotización ofreciada por el _oráculo_.
- En la _blockchain_ no se puede realizar este cambio por lo que asumimos que utilizamo un NFT que representa a la moneda USD.

# Recompensa o incentivo
- Es necesario incentivar al _oráculo_ para que proporcione la información por lo que se fija un comisión por su uso en una trasacción, por ejemplo, 1 ADA.

# Transacción
- El proceso de la transacción se corresponde con el siguiente diagrama
![](./swap_transaction.png)

- Entradas (UTXo):
    - **Oracle**: Cotización de ADA/USD (NFT 1.75)
        - **use**:
    - **Swap**: Nº de ADA que se desean intercambiar (100 ADA)
    - **Buyer**: Comprador de los ADA a la cotización proporcionada por el oráculo y comisión ( 175 USD + 1 ADA)
- Salidas (UTXo)
    - **Oracle**: El NFT, que no varía, y su la comisión a pagar (NTF 1.75 + 1 ADA
    - **Seller**: Recibe los USD (175 USD)
    - **Buyer**: Recibe los ADA.


# Actualización del valor de los datos de un Oráculo y recolección de comisiones.
- Esto es un tanto extraño. Esta claro que los datos que proporciona el oráculo pueden cambiar con el tiempo y que, además el dueño del oráculo debe ser capaz de cobrar las comisiones por su uso.
- En este caso de uso se ha añadido una operación que:
    - Permite cambiar el valor de la cotización
    - Permite recoger las comisiones asociadas al uso de este dato, si las tiene.

![](./oracle_fee_transaction.png)

- La trasacción _update_ la realiza el _oráculo_
    - Para propocionar un valor nuevo
    - Para cobrar las comisiones.

# Implementación
- Vamos a analizar el código que implementa las operaciones que hemos descrito anteriormente.
## Oráculo: Core.hs

```haskell
data Oracle = Oracle
    { oSymbol   :: !CurrencySymbol
    , oOperator :: !PubKeyHash
    , oFee      :: !Integer
    , oAsset    :: !AssetClass
    } deriving (Show, Generic, FromJSON, ToJSON, Prelude.Eq, Prelude.Ord)

data OracleRedeemer = Update | Use
    deriving Show

{-# INLINABLE oracleTokenName #-}
oracleTokenName :: TokenName
oracleTokenName = TokenName emptyByteString

{-# INLINABLE oracleAsset #-}
oracleAsset :: Oracle -> AssetClass
oracleAsset oracle = AssetClass (oSymbol oracle, oracleTokenName)

{-# INLINABLE oracleValue #-}
oracleValue :: TxOut -> (DatumHash -> Maybe Datum) -> Maybe Integer
oracleValue o f = do
    dh      <- txOutDatum o
    Datum d <- f dh
    PlutusTx.fromBuiltinData d
```

- _oSymbol_: Símbolo del NFT que vamos a utilizar. _TokenName_ estará vacío.
- _oOperator_: _Hash_ de la clave pública del dueño del oráculo.
- _oFee_ : La comisión asociada al uso del dato.
- _oAsset_ : Activo por el que se va a intercambiar los ADA. En el ejemplo, USD, como este no existe
- _Redeemer_ : Dos operaciones sobre este UTXo: 
    - _update_: Para cambiar el valor del dato proporcionado y recolectar las comisiones
    - _use_ : Para usar el valor en una transacciónde _swap_.

- _oracleAsset_: Es el NFT que utilizamos en este oráculo. El nombre del token será la cadena vacía.
- _oracleValue_: Es el valor del dato que ofrece el oráculo, la cotización (será un entero para simplificar)
    - Esta función es una Mónada.

### Validación (_on chain_)
- Este código valida la UTXo del oráculo. Es el núcleo de nuestro proceso.
- Validación de la UTxo del oráculo según la operación a realizar (_update_, _use_).
```haskell
mkOracleValidator :: Oracle -> Integer -> OracleRedeemer -> ScriptContext -> Bool
mkOracleValidator oracle x r ctx =
    traceIfFalse "token missing from input"  inputHasToken  &&
    traceIfFalse "token missing from output" outputHasToken &&
    case r of
        Update -> traceIfFalse "operator signature missing" (txSignedBy info $ oOperator oracle) &&
                  traceIfFalse "invalid output datum"       validOutputDatum
        Use    -> traceIfFalse "oracle value changed"       (outputDatum == Just x)              &&
                  traceIfFalse "fees not paid"              feesPaid
```
- Hay que comprobar:
    - El NFT de la UTXo de entrada (la que se va a consumir)
    - El NFT de la UTXo de salida (la que se va a generar)
    - Si _update_:
        - Las firmas deben coincidir: UTXo y dueño del oráculo (solo el dueño puede cambiar un valor).
        - El valor de la cotización debe ser del tipo correcto.
    - Si _use_: 
        - La cotización utilizada (para realizar el _swap_) debe ser la del oráculo.
        - La comisión de uso debe haberse pagado.
        
### Oráculo (_off chain_)
- _startOracle_: Crea un oráculo: NFT, clave, comisiones, activo (USD)
    - Lo más interesante es la creación del NFT, que necesita un contrato con un script de minado:
    ```haskell
    startOracle :: forall w s. OracleParams -> Contract w s Text Oracle
    startOracle op = do
    pkh <- pubKeyHash <$> Contract.ownPubKey
    osc <- mapError (pack . show) (mintContract pkh [(oracleTokenName, 1)] :: Contract w s CurrencyError OneShotCurrency)
    let cs     = Currency.currencySymbol osc
        oracle = Oracle
            { oSymbol   = cs
            , oOperator = pkh
            , oFee      = opFees op
            , oAsset    = AssetClass (opSymbol op, opToken op)
            }
    logInfo @String $ "started oracle " ++ show oracle
    return oracle
    ```
    - La creación del NFT debe realizarse antes de emitir el dato puesto que puede ser, es, lenta (un par de _slots_). Como van en parejas (NFT, dato) hay que acuñar el NFT antes.
    - _mintContract_ es una función definida en un paquete que es una implementación más genérica de NFT. 
    ```
    >:t mintContract
    mintContract
    :: AsCurrencyError e =>
        PubKeyHash
        -> [(TokenName, Integer)] -> Contract w s e OneShotCurrency
       	-- Defined in ‘Plutus.Contracts.Currency’

    Prelude Plutus.Contract Plutus.Contracts.Currency Ledger Week06.Oracle.Core> :t mapError
    mapError :: (e -> e') -> Contract w s e a -> Contract w s e' a
    Prelude Plutus.Contract Plutus.Contracts.Currency Ledger Week06.Oracle.Core> :i CurrencyError
    type CurrencyError :: *
    newtype CurrencyError = CurContractError ContractError
        -- Defined in ‘Plutus.Contracts.Currency’
    instance Eq CurrencyError -- Defined in ‘Plutus.Contracts.Currency’
    instance Show CurrencyError
    -- Defined in ‘Plutus.Contracts.Currency’
    instance AsContractError CurrencyError
    -- Defined in ‘Plutus.Contracts.Currency’
    instance AsCurrencyError CurrencyError
    -- Defined in ‘Plutus.Contracts.Currency’

    ```
    - Esta función tiene una particularidad, el tipo de error (_AsCurrencyError_): 

- _updateOracle_: Cambia el valor de una cotización.
- _findOracle_: Busca la cotización que queremos actualizar.

```haskell
updateOracle :: forall w s. Oracle -> Integer -> Contract w s Text ()
updateOracle oracle x = do
    m <- findOracle oracle
    let c = Constraints.mustPayToTheScript x $ assetClassValue (oracleAsset oracle) 1
    case m of
        Nothing -> do
            ledgerTx <- submitTxConstraints (typedOracleValidator oracle) c
            awaitTxConfirmed $ txId ledgerTx
            logInfo @String $ "set initial oracle value to " ++ show x
        Just (oref, o,  _) -> do
            let lookups = Constraints.unspentOutputs (Map.singleton oref o)     <>
                          Constraints.typedValidatorLookups (typedOracleValidator oracle) <>
                          Constraints.otherScript (oracleValidator oracle)
                tx      = c <> Constraints.mustSpendScriptOutput oref (Redeemer $ PlutusTx.toBuiltinData Update)
            ledgerTx <- submitTxConstraintsWith @Oracling lookups tx
            awaitTxConfirmed $ txId ledgerTx
            logInfo @String $ "updated oracle value to " ++ show x

findOracle :: forall w s. Oracle -> Contract w s Text (Maybe (TxOutRef, TxOutTx, Integer))
findOracle oracle = do
    utxos <- Map.filter f <$> utxoAt (oracleAddress oracle)
    return $ case Map.toList utxos of
        [(oref, o)] -> do
            x <- oracleValue (txOutTxOut o) $ \dh -> Map.lookup dh $ txData $ txOutTxTx o
            return (oref, o, x)
        _           -> Nothing
  where
    f :: TxOutTx -> Bool
    f o = assetClassValueOf (txOutValue $ txOutTxOut o) (oracleAsset oracle) == 1

type OracleSchema = Endpoint "update" Integer
```
- _runOracle_:
```haskell
runOracle :: OracleParams -> Contract (Last Oracle) OracleSchema Text ()
runOracle op = do
    oracle <- startOracle op
    tell $ Last $ Just oracle
    go oracle
  where
    go :: Oracle -> Contract (Last Oracle) OracleSchema Text a
    go oracle = do
        x <- endpoint @"update"
        updateOracle oracle x
        go oracle
```
- _tell_ permite comunicar datos fuera de un contrato. Recibe una  mónada.
    - _Last_: devuelve el último valor, en este caso, el valor del oráculo.

    
# Contrato: Swap.hs
- Contrato para intercambiar ADA/USDT.
- Me remito a las notas en inglés. Es un proceso complejo. Mas adelante lo revisaré.

# Fondos: Funds.hs
- Es un bucle que muestra los fondos de nuestro monedero.

# Pruebas: Test.hs
- Fijamos las monedas (USDT)
- Preparamos los monederos con dinero en Lovelaces y USDT (100M)

## Resultado
```
test
Slot 00000: TxnValidate 67305e557c83d950979655861b470d7d1df6dac87883999662ad2ec521334698
Slot 00000: SlotAdd Slot 1
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Contract instance started
Slot 00001: W1: TxSubmit: e07f3c549f071d3d9c02e2b90c1a18ecd4bcf16bce2b4889697abf10b6be7b3f
Slot 00001: TxnValidate e07f3c549f071d3d9c02e2b90c1a18ecd4bcf16bce2b4889697abf10b6be7b3f
Slot 00001: SlotAdd Slot 2
Slot 00002: *** CONTRACT LOG: "started oracle Oracle {oSymbol = 5bd6aba4c7600ee7fec421308bf39488cbdc6ea6e13bb7acb015681c, oOperator = 35dedd2982a03cf39e7dce03c839994ffdec2ec6b04f1cf2d40e61a3, oFee = 1000000, oAsset = (ff,\"USDT\")}"
Slot 00002: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Sending contract state to Thread 0
Slot 00002: *** USER LOG: Oracle {oSymbol = 5bd6aba4c7600ee7fec421308bf39488cbdc6ea6e13bb7acb015681c, oOperator = 35dedd2982a03cf39e7dce03c839994ffdec2ec6b04f1cf2d40e61a3, oFee = 1000000, oAsset = (ff,"USDT")}
Slot 00002: 00000000-0000-4000-8000-000000000001 {Contract instance for wallet 2}:
  Contract instance started
Slot 00002: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'update' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "update")]),Object (fromList [("unEndpointValue",Number 1500000.0)])]),("tag",String "ExposeEndpointResp")])
Slot 00002: W1: TxSubmit: d31619b49698664c53ad08ac7699c4c8959f5f3de7f4ddb5bd9abc4205161525
Slot 00002: TxnValidate d31619b49698664c53ad08ac7699c4c8959f5f3de7f4ddb5bd9abc4205161525
Slot 00002: SlotAdd Slot 3
Slot 00003: *** CONTRACT LOG: "Oracle value: 1500000"
Slot 00003: *** CONTRACT LOG: "set initial oracle value to 1500000"
Slot 00003: SlotAdd Slot 4
Slot 00004: *** CONTRACT LOG: "Oracle value: 1500000"
Slot 00004: SlotAdd Slot 5
Slot 00005: 00000000-0000-4000-8000-000000000002 {Contract instance for wallet 1}:
  Contract instance started
Slot 00005: 00000000-0000-4000-8000-000000000003 {Contract instance for wallet 3}:
  Contract instance started
Slot 00005: 00000000-0000-4000-8000-000000000004 {Contract instance for wallet 4}:
  Contract instance started
Slot 00005: *** CONTRACT LOG: "own funds: [(,\"\",99990246),(ff,\"USDT\",100000000)]"
Slot 00005: 00000000-0000-4000-8000-000000000005 {Contract instance for wallet 5}:
  Contract instance started
Slot 00005: *** CONTRACT LOG: "own funds: [(,\"\",100000000),(ff,\"USDT\",100000000)]"
Slot 00005: 00000000-0000-4000-8000-000000000006 {Contract instance for wallet 3}:
  Contract instance started
Slot 00005: *** CONTRACT LOG: "own funds: [(,\"\",100000000),(ff,\"USDT\",100000000)]"
Slot 00005: 00000000-0000-4000-8000-000000000007 {Contract instance for wallet 4}:
  Contract instance started
Slot 00005: *** CONTRACT LOG: "own funds: [(,\"\",100000000),(ff,\"USDT\",100000000)]"
Slot 00005: 00000000-0000-4000-8000-000000000008 {Contract instance for wallet 5}:
  Contract instance started
Slot 00005: *** CONTRACT LOG: "Oracle value: 1500000"
Slot 00005: 00000000-0000-4000-8000-000000000006 {Contract instance for wallet 3}:
  Receive endpoint call on 'offer' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "offer")]),Object (fromList [("unEndpointValue",Number 1.0e7)])]),("tag",String "ExposeEndpointResp")])
Slot 00005: W3: TxSubmit: e6558c0f6030abaf6ed3588c4eb5d1839941fa00588e593a69346d1d9510f545
Slot 00005: 00000000-0000-4000-8000-000000000007 {Contract instance for wallet 4}:
  Receive endpoint call on 'offer' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "offer")]),Object (fromList [("unEndpointValue",Number 2.0e7)])]),("tag",String "ExposeEndpointResp")])
Slot 00005: W4: TxSubmit: 57df98687327666249f80c2d671d41afaf5d2285ee2fe34f72832f9095a0d212
Slot 00005: TxnValidate 57df98687327666249f80c2d671d41afaf5d2285ee2fe34f72832f9095a0d212
Slot 00005: TxnValidate e6558c0f6030abaf6ed3588c4eb5d1839941fa00588e593a69346d1d9510f545
Slot 00005: SlotAdd Slot 6
Slot 00006: *** CONTRACT LOG: "own funds: [(,\"\",99990246),(ff,\"USDT\",100000000)]"
Slot 00006: *** CONTRACT LOG: "offered 10000000 lovelace for swap"
Slot 00006: *** CONTRACT LOG: "own funds: [(,\"\",89999990),(ff,\"USDT\",100000000)]"
Slot 00006: *** CONTRACT LOG: "offered 20000000 lovelace for swap"
Slot 00006: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",100000000)]"
Slot 00006: *** CONTRACT LOG: "own funds: [(,\"\",100000000),(ff,\"USDT\",100000000)]"
Slot 00006: *** CONTRACT LOG: "Oracle value: 1500000"
Slot 00006: SlotAdd Slot 7
Slot 00007: *** CONTRACT LOG: "own funds: [(,\"\",99990246),(ff,\"USDT\",100000000)]"
Slot 00007: *** CONTRACT LOG: "own funds: [(,\"\",89999990),(ff,\"USDT\",100000000)]"
Slot 00007: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",100000000)]"
Slot 00007: *** CONTRACT LOG: "own funds: [(,\"\",100000000),(ff,\"USDT\",100000000)]"
Slot 00007: *** CONTRACT LOG: "Oracle value: 1500000"
Slot 00007: SlotAdd Slot 8
Slot 00008: *** CONTRACT LOG: "own funds: [(,\"\",99990246),(ff,\"USDT\",100000000)]"
Slot 00008: *** CONTRACT LOG: "own funds: [(,\"\",89999990),(ff,\"USDT\",100000000)]"
Slot 00008: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",100000000)]"
Slot 00008: *** CONTRACT LOG: "own funds: [(,\"\",100000000),(ff,\"USDT\",100000000)]"
Slot 00008: *** CONTRACT LOG: "Oracle value: 1500000"
Slot 00008: 00000000-0000-4000-8000-000000000008 {Contract instance for wallet 5}:
  Receive endpoint call on 'use' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "use")]),Object (fromList [("unEndpointValue",Array [])])]),("tag",String "ExposeEndpointResp")])
Slot 00008: *** CONTRACT LOG: "own funds: [(,\"\",100000000),(ff,\"USDT\",100000000)]"
Slot 00008: *** CONTRACT LOG: "available assets: 100000000"
Slot 00008: *** CONTRACT LOG: "found oracle, exchange rate 1500000"
Slot 00008: W5: TxSubmit: a581e562b2005b48331d66bec3931d468fb6d930490f5420c73bddc7b25e7970
Slot 00008: TxnValidate a581e562b2005b48331d66bec3931d468fb6d930490f5420c73bddc7b25e7970
Slot 00008: SlotAdd Slot 9
Slot 00009: *** CONTRACT LOG: "own funds: [(,\"\",99990246),(ff,\"USDT\",100000000)]"
Slot 00009: *** CONTRACT LOG: "own funds: [(,\"\",89999990),(ff,\"USDT\",100000000)]"
Slot 00009: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00009: *** CONTRACT LOG: "made swap with price [(ff,\"USDT\",30000000)]"
Slot 00009: *** CONTRACT LOG: "own funds: [(,\"\",118977235),(ff,\"USDT\",70000000)]"
Slot 00009: *** CONTRACT LOG: "Oracle value: 1500000"
Slot 00009: SlotAdd Slot 10
Slot 00010: *** CONTRACT LOG: "own funds: [(,\"\",99990246),(ff,\"USDT\",100000000)]"
Slot 00010: *** CONTRACT LOG: "own funds: [(,\"\",89999990),(ff,\"USDT\",100000000)]"
Slot 00010: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00010: *** CONTRACT LOG: "own funds: [(,\"\",118977235),(ff,\"USDT\",70000000)]"
Slot 00010: *** CONTRACT LOG: "Oracle value: 1500000"
Slot 00010: SlotAdd Slot 11
Slot 00011: *** CONTRACT LOG: "own funds: [(,\"\",99990246),(ff,\"USDT\",100000000)]"
Slot 00011: *** CONTRACT LOG: "own funds: [(,\"\",89999990),(ff,\"USDT\",100000000)]"
Slot 00011: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00011: *** CONTRACT LOG: "own funds: [(,\"\",118977235),(ff,\"USDT\",70000000)]"
Slot 00011: *** CONTRACT LOG: "Oracle value: 1500000"
Slot 00011: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'update' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "update")]),Object (fromList [("unEndpointValue",Number 1700000.0)])]),("tag",String "ExposeEndpointResp")])
Slot 00011: W1: TxSubmit: 5552d32ed422c7a849ed45829ffa7c326fe185562ac7a2ec57c6b7ad17d7b878
Slot 00011: TxnValidate 5552d32ed422c7a849ed45829ffa7c326fe185562ac7a2ec57c6b7ad17d7b878
Slot 00011: SlotAdd Slot 12
Slot 00012: *** CONTRACT LOG: "own funds: [(,\"\",100978827),(ff,\"USDT\",100000000)]"
Slot 00012: *** CONTRACT LOG: "own funds: [(,\"\",89999990),(ff,\"USDT\",100000000)]"
Slot 00012: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00012: *** CONTRACT LOG: "own funds: [(,\"\",118977235),(ff,\"USDT\",70000000)]"
Slot 00012: *** CONTRACT LOG: "Oracle value: 1700000"
Slot 00012: *** CONTRACT LOG: "updated oracle value to 1700000"
Slot 00012: SlotAdd Slot 13
Slot 00013: *** CONTRACT LOG: "own funds: [(,\"\",100978827),(ff,\"USDT\",100000000)]"
Slot 00013: *** CONTRACT LOG: "own funds: [(,\"\",89999990),(ff,\"USDT\",100000000)]"
Slot 00013: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00013: *** CONTRACT LOG: "own funds: [(,\"\",118977235),(ff,\"USDT\",70000000)]"
Slot 00013: *** CONTRACT LOG: "Oracle value: 1700000"
Slot 00013: SlotAdd Slot 14
Slot 00014: *** CONTRACT LOG: "own funds: [(,\"\",100978827),(ff,\"USDT\",100000000)]"
Slot 00014: *** CONTRACT LOG: "own funds: [(,\"\",89999990),(ff,\"USDT\",100000000)]"
Slot 00014: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00014: *** CONTRACT LOG: "own funds: [(,\"\",118977235),(ff,\"USDT\",70000000)]"
Slot 00014: *** CONTRACT LOG: "Oracle value: 1700000"
Slot 00014: 00000000-0000-4000-8000-000000000008 {Contract instance for wallet 5}:
  Receive endpoint call on 'use' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "use")]),Object (fromList [("unEndpointValue",Array [])])]),("tag",String "ExposeEndpointResp")])
Slot 00014: *** CONTRACT LOG: "own funds: [(,\"\",118977235),(ff,\"USDT\",70000000)]"
Slot 00014: *** CONTRACT LOG: "available assets: 70000000"
Slot 00014: *** CONTRACT LOG: "found oracle, exchange rate 1700000"
Slot 00014: W5: TxSubmit: 6c74b88ef25dda50383cc84a8c2cc8c61a6d220c4203bc7def1fbfff1beb055f
Slot 00014: TxnValidate 6c74b88ef25dda50383cc84a8c2cc8c61a6d220c4203bc7def1fbfff1beb055f
Slot 00014: SlotAdd Slot 15
Slot 00015: *** CONTRACT LOG: "own funds: [(,\"\",100978827),(ff,\"USDT\",100000000)]"
Slot 00015: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00015: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00015: *** CONTRACT LOG: "made swap with price [(ff,\"USDT\",17000000)]"
Slot 00015: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Slot 00015: *** CONTRACT LOG: "Oracle value: 1700000"
Slot 00015: SlotAdd Slot 16
Slot 00016: *** CONTRACT LOG: "own funds: [(,\"\",100978827),(ff,\"USDT\",100000000)]"
Slot 00016: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00016: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00016: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Slot 00016: *** CONTRACT LOG: "Oracle value: 1700000"
Slot 00016: SlotAdd Slot 17
Slot 00017: *** CONTRACT LOG: "own funds: [(,\"\",100978827),(ff,\"USDT\",100000000)]"
Slot 00017: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00017: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00017: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Slot 00017: *** CONTRACT LOG: "Oracle value: 1700000"
Slot 00017: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'update' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "update")]),Object (fromList [("unEndpointValue",Number 1800000.0)])]),("tag",String "ExposeEndpointResp")])
Slot 00017: W1: TxSubmit: 47aa2375f10483c8cd66fe034e3b3305a4de93a3fec10ab4fbee3b866b32c348
Slot 00017: TxnValidate 47aa2375f10483c8cd66fe034e3b3305a4de93a3fec10ab4fbee3b866b32c348
Slot 00017: SlotAdd Slot 18
Slot 00018: *** CONTRACT LOG: "own funds: [(,\"\",101967408),(ff,\"USDT\",100000000)]"
Slot 00018: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00018: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00018: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Slot 00018: *** CONTRACT LOG: "Oracle value: 1800000"
Slot 00018: *** CONTRACT LOG: "updated oracle value to 1800000"
Slot 00018: SlotAdd Slot 19
Slot 00019: *** CONTRACT LOG: "own funds: [(,\"\",101967408),(ff,\"USDT\",100000000)]"
Slot 00019: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00019: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00019: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Slot 00019: *** CONTRACT LOG: "Oracle value: 1800000"
Slot 00019: SlotAdd Slot 20
Slot 00020: *** CONTRACT LOG: "own funds: [(,\"\",101967408),(ff,\"USDT\",100000000)]"
Slot 00020: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00020: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00020: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Slot 00020: *** CONTRACT LOG: "Oracle value: 1800000"
Slot 00020: 00000000-0000-4000-8000-000000000006 {Contract instance for wallet 3}:
  Receive endpoint call on 'retrieve' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "retrieve")]),Object (fromList [("unEndpointValue",Array [])])]),("tag",String "ExposeEndpointResp")])
Slot 00020: *** CONTRACT LOG: "no swaps found"
Slot 00020: 00000000-0000-4000-8000-000000000007 {Contract instance for wallet 4}:
  Receive endpoint call on 'retrieve' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "retrieve")]),Object (fromList [("unEndpointValue",Array [])])]),("tag",String "ExposeEndpointResp")])
Slot 00020: *** CONTRACT LOG: "no swaps found"
Slot 00020: SlotAdd Slot 21
Slot 00021: *** CONTRACT LOG: "own funds: [(,\"\",101967408),(ff,\"USDT\",100000000)]"
Slot 00021: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00021: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00021: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Slot 00021: *** CONTRACT LOG: "Oracle value: 1800000"
Slot 00021: SlotAdd Slot 22
Slot 00022: *** CONTRACT LOG: "own funds: [(,\"\",101967408),(ff,\"USDT\",100000000)]"
Slot 00022: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00022: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00022: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Slot 00022: *** CONTRACT LOG: "Oracle value: 1800000"
Slot 00022: SlotAdd Slot 23
Slot 00023: *** CONTRACT LOG: "own funds: [(,\"\",101967408),(ff,\"USDT\",100000000)]"
Slot 00023: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00023: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00023: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Slot 00023: *** CONTRACT LOG: "Oracle value: 1800000"
Slot 00023: SlotAdd Slot 24
Slot 00024: *** CONTRACT LOG: "own funds: [(,\"\",101967408),(ff,\"USDT\",100000000)]"
Slot 00024: *** CONTRACT LOG: "own funds: [(ff,\"USDT\",117000000),(,\"\",89999990)]"
Slot 00024: *** CONTRACT LOG: "own funds: [(,\"\",79999990),(ff,\"USDT\",130000000)]"
Slot 00024: *** CONTRACT LOG: "own funds: [(,\"\",127954470),(ff,\"USDT\",53000000)]"
Final balances
Wallet 1: 
    {, ""}: 101967408
    {ff, "USDT"}: 100000000
Wallet 2: 
    {, ""}: 100000000
    {ff, "USDT"}: 100000000
Wallet 3: 
    {, ""}: 89999990
    {ff, "USDT"}: 117000000
Wallet 4: 
    {ff, "USDT"}: 130000000
    {, ""}: 79999990
Wallet 5: 
    {, ""}: 127954470
    {ff, "USDT"}: 53000000
Wallet 6: 
    {, ""}: 100000000
    {ff, "USDT"}: 100000000
Wallet 7: 
    {, ""}: 100000000
    {ff, "USDT"}: 100000000
Wallet 8: 
    {, ""}: 100000000
    {ff, "USDT"}: 100000000
Wallet 9: 
    {, ""}: 100000000
    {ff, "USDT"}: 100000000
Wallet 10: 
    {, ""}: 100000000
    {ff, "USDT"}: 100000000
Script 276678f8c1954db1183f3c8dce02593b7e777b77dbb27ff5477afdb1: 
    {5bd6aba4c7600ee7fec421308bf39488cbdc6ea6e13bb7acb015681c, ""}: 1

```

# Plutus Application Backend: PAB.hs
- Vamos a crear un ejecutables que ejecute los contratos.


# Ejercicios
- Probar el sistema y ejecutar varias operaciones con los clientes dados.
- Crear clientes (frontends) en otros lenguajes.
- Añadir varios oráculos, por ejemplo 3, de distintas fuentes.
    - Una estrategia para calcular el precio sería aquel que esté en el medio, desechando el máximo y el mínimo.
    - Una restricción sería que los tres estuviesen presentes.
- Soporte para varios tokens (ETH, BTC)
