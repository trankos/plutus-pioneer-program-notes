Clase 04 [Lecture04](https://www.youtube.com/watch?v=g4lvA14I-Jg)

# Introducción
- Hasta ahora hemos analizado el funcionamiento de los scripts _on chain_, validaciones, que se compilan como código Plutus y que se ejecutan en los nodos de la red para validar una transacción.
    - En breve futuro veremos como con estos scripts se pueden realizar, a parte, de validaciones otras operaciones como el _acuñado_, (_minting_ , creación), o la _fundición_, ( _burning_, eliminación )

- En esta lección vamos a estudiar sobre el códig _off-chain_, que nos permite construir transacciónes en los monederos

# Off chain
- Ya se comentó que el código de los script _on_chain_ debe ser compilado para que funcione en Plutus. Además todo el código que utilicemos debe incluirse en la compilación, mediante el pragma INLINEABLE
```haskell
{-# INLINABLE mkValidator #-}
```
- Tecnicamente, no son más que funciones Haskell, y suelen ser muy sencillas. De hecho el validador tiene un firma con tres parámetros (_Datum_, _Redeemer_ , _ScriptContext_) y devuelve un valor booleano, puede que alguno más si está parametrizado. Pero es evidente que no podemos utilizar otras funciones de otras Haskell que, ni siquiera, están escritas en Plutus. Digamos que las capacidades que tenemos para codificar operaciones más complejas son reducidas: el código que creemos más las posibilidades que ofrece Plutus.
- Sin embargo, el código _off chain_ no tiene ninguna restricción, es Haskell con todas sus posibilidades. pero tiene el incoveniente de que es más complejo.
- El código del monedero, _off chain_, está escrito en una mónada (_monad_) especial denominada _Contract Monad_

# Haskell: Mónadas
- A continuación, un paréntesis para tratar temas propios del lenguaje Haskell, como son las Mónadas.
- En lenguajes imperativos, como Java, es imposible saber si varias llamadas a la misma función devolverán el mismo valor.
```java
public static int foo(){
....
}
...
... foo() ... foo()
```
- ¿Por qué? Porque dentro del código de la función se pueden producir procesos de E/S (I/O, IO), que cambien el resultado. Por esto debemos conocer el código exacto de la función para poder comprenderlo o razonar sobre él o probarlo.
- En Haskell, sin embargo, al ser un _lenguaje funcional_ puro, las cosas cambian:
```haskell
foo :: Int
foo = ...

... foo ... foo ...
```
- En este caso si el valor de foo en la primera llamada es 7, en la segunda llamada será, _NECESARIAMENTE, 7. Es decir, una llamada a una función con los mismos parámetros siempre devolverá el mismo resultado. 
    > ¿El compilador impide la compilación de código con "efectos colaterales" ?

- Esta propiedad se denomina _TRANSPARENCIA REFERENCIAL_, _referential transparency_.
    - Esta propiedad del lenguaje es muy matemática, pero un tanto inútil en el mundo real, puesto que los programas tienen que interactuar con otros elementos y para esto es necesario que Haskell pueda gestionar estos efectos colaterales (E/S)
## Mónada de E/S (IO Monad)
- Veamos esta versión de _foo()_:

```haskell
foo :: IO Int -- IO es un constructor de tipos
foo = ...
```
- IO es un constructor de tipos de datos que incluye cierta _receta_ para construir tipos de datos enteros y que permite realizar operaciones de E/S: es una lista de operaciones que, como resultado final devuelven un dato de tipo Int (entero).
    - Parece que la transparencia se rompe pero hay que tener en cuenta que el constructor devuelve la _lista de operaciones a realizar_ no el valor del resultado de esa lista de operaciones (las operaciones no se ejecutan). Estas solo se aplican cuando se llama a la función dentro de la ejecución del programa (además Haskell utiliza evaluación perezosa _lazy evaluation_)
    > No se si se exige que se ejecuten en una programa principal (main) o un módulo principal. Correcto, un ejecutable debe tener un fichero con un módulo main.
    ```cabal
    executable hello
        hs-source-dirs:      app
        main-is:             hello.hs
        build-depends:       base ^>=4.14.1.0
        default-language:    Haskell2010
        ghc-options:         -Wall -O2
    ```
    ```haskell
    main :: IO ()
    main = putStrLn "Hello World!"
    ```

- Las operaciones se pueden concatenar de varias formas o aplicarlas de forma secuencial
    - Functor: 
        ```haskell
        fmap (map toUpper) getLine
        hola
        "HOLA"
        ```
    - _>>_ : Concatenación
        ```
        putStrLn "Hello" >> putStrLn "World"
        Hello
        World
        ```
    - _>>=_ : Binding (ligadas: la salida es una es la entrada de otra.)
        ```
        *Main Data.Char> :t (>>=)
        (>>=) :: Monad m => m a -> (a -> m b) -> m b
        *Main Data.Char> getLine >>= putStrLn
        Hola
        Hola
        *Main Data.Char> 
        ```
    - _return_ : Permite construir _recetas_ (_monads_) que devuelven un resultado sin efectos colaterales ¿?


# Maybe, Either
- Tipos de datos: ejemplos de uso en [maybe](../code/Maybe.hs) y [either](../code/Either.hs)

# EmulatrorTrace

- Como emitir trazas de ejecución. 

```
runEmulatorTrace ::
  EmulatorConfig
  -> FeeConfig
  -> EmulatorTrace ()
  -> ([Wallet.Emulator.MultiAgent.EmulatorEvent], Maybe EmulatorErr,
      Wallet.Emulator.MultiAgent.EmulatorState)
        -- Defined in ‘Plutus.Trace.Emulator’
```

> Prelude Plutus.Contract.Trace Data.Default Plutus.Trace.Emulator Ledger.Fee Week04.Trace> runEmulatorTrace def def $ return ()

>runEmulatorTraceIO :: EmulatorTrace () -> IO ()
        -- Defined in ‘Plutus.Trace.Emulator’


```
relude Plutus.Contract.Trace Data.Default Plutus.Trace.Emulator Ledger.Fee Week04.Trace> runEmulatorTraceIO $ return ()
Slot 00000: TxnValidate 0636250aef275497b4f3807d661a299e34e53e5ad3bc1110e43d1f3420bc8fae
Slot 00000: SlotAdd Slot 1
Slot 00001: SlotAdd Slot 2
Final balances
Wallet 1: 
    {, ""}: 100000000
Wallet 2: 
    {, ""}: 100000000
Wallet 3: 
    {, ""}: 100000000
Wallet 4: 
    {, ""}: 100000000
Wallet 5: 
    {, ""}: 100000000
Wallet 6: 
    {, ""}: 100000000
Wallet 7: 
    {, ""}: 100000000
Wallet 8: 
    {, ""}: 100000000
Wallet 9: 
    {, ""}: 100000000
Wallet 10: 
    {, ""}: 100000000

:i TraceConfig 
type TraceConfig :: *
data TraceConfig
  = TraceConfig {showEvent :: Wallet.Emulator.MultiAgent.EmulatorEvent'
                              -> Maybe String,
                 outputHandle :: GHC.IO.Handle.Types.Handle}
        -- Defined in ‘Plutus.Trace.Emulator’
instance Default TraceConfig -- Defined in ‘Plutus.Trace.Emulator’

```

# BuiltinData
- Un nuevo tipo de datos para manejar los datos del script de validación.

# Trace
```haskell
import Ledger
import Ledger.TimeSlot
import Plutus.Trace.Emulator      as Emulator
import Wallet.Emulator.Wallet

import Week04.Vesting

-- Contract w s e a
-- EmulatorTrace a

test :: IO ()
test = runEmulatorTraceIO myTrace

myTrace :: EmulatorTrace ()
myTrace = do
    h1 <- activateContractWallet (Wallet 1) endpoints
    h2 <- activateContractWallet (Wallet 2) endpoints
    callEndpoint @"give" h1 $ GiveParams
        { gpBeneficiary = pubKeyHash $ walletPubKey $ Wallet 2
        , gpDeadline    = slotToBeginPOSIXTime def 20
        , gpAmount      = 10000000
        }
    void $ waitUntilSlot 20
    callEndpoint @"grab" h2 ()
    s <- waitNSlots 1
    Extras.logInfo $ "reached " ++ show s
```
- En este ejemplo vamos a recrear una donación y la recuperación de la donación.
- Ejecutando la función _test_ ejecutamos y trazamos las operaciones de la función _myTrace_. 
    - La salida es similar a la que obtenemos en la simulación a través del _plutus-playground_.

```
 :l src/Week04/Trace.hs 

<no location info>: warning: [-Wmissing-home-modules]
    These modules are needed for compilation but not listed in your .cabal file's other-modules: 
        Week04.Vesting
Ok, two modules loaded.
Prelude Plutus.Contract.Trace Data.Default Plutus.Trace.Emulator Ledger.Fee Week04.Trace> test
Slot 00000: TxnValidate 0636250aef275497b4f3807d661a299e34e53e5ad3bc1110e43d1f3420bc8fae
Slot 00000: SlotAdd Slot 1
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Contract instance started
Slot 00001: 00000000-0000-4000-8000-000000000001 {Contract instance for wallet 2}:
  Contract instance started
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'give' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "give")]),Object (fromList [("unEndpointValue",Object (fromList [("gpAmount",Number 1.0e7),("gpBeneficiary",Object (fromList [("getPubKeyHash",String "977efb35ab621d39dbeb7274ec7795a34708ff4d25a01a1df04c1f27")])),("gpDeadline",Number 1.596059111e12)]))])]),("tag",String "ExposeEndpointResp")])
Slot 00001: W1: TxSubmit: 09a886ba122bcac887396299f37857626e986637c4f2c6e0d433f137c04174b8
Slot 00001: TxnValidate 09a886ba122bcac887396299f37857626e986637c4f2c6e0d433f137c04174b8
Slot 00001: SlotAdd Slot 2
Slot 00002: *** CONTRACT LOG: "made a gift of 10000000 lovelace to 977efb35ab621d39dbeb7274ec7795a34708ff4d25a01a1df04c1f27 with deadline POSIXTime {getPOSIXTime = 1596059111000}"
Slot 00002: SlotAdd Slot 3
Slot 00003: SlotAdd Slot 4
Slot 00004: SlotAdd Slot 5
Slot 00005: SlotAdd Slot 6
Slot 00006: SlotAdd Slot 7
Slot 00007: SlotAdd Slot 8
Slot 00008: SlotAdd Slot 9
Slot 00009: SlotAdd Slot 10
Slot 00010: SlotAdd Slot 11
Slot 00011: SlotAdd Slot 12
Slot 00012: SlotAdd Slot 13
Slot 00013: SlotAdd Slot 14
Slot 00014: SlotAdd Slot 15
Slot 00015: SlotAdd Slot 16
Slot 00016: SlotAdd Slot 17
Slot 00017: SlotAdd Slot 18
Slot 00018: SlotAdd Slot 19
Slot 00019: SlotAdd Slot 20
Slot 00020: 00000000-0000-4000-8000-000000000001 {Contract instance for wallet 2}:
  Receive endpoint call on 'grab' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "grab")]),Object (fromList [("unEndpointValue",Array [])])]),("tag",String "ExposeEndpointResp")])
Slot 00020: W2: TxSubmit: c9ccd509266709242cd43090f15e26c383dc68f2e0d72e7c250d4d485b7441cf
Slot 00020: TxnValidate c9ccd509266709242cd43090f15e26c383dc68f2e0d72e7c250d4d485b7441cf
Slot 00020: SlotAdd Slot 21
Slot 00021: *** USER LOG: reached Slot {getSlot = 21}
Slot 00021: *** CONTRACT LOG: "collected gifts"
Slot 00021: SlotAdd Slot 22
Final balances
Wallet 1: 
    {, ""}: 89999990
Wallet 2: 
    {, ""}: 109989513
Wallet 3: 
    {, ""}: 100000000
Wallet 4: 
    {, ""}: 100000000
Wallet 5: 
    {, ""}: 100000000
Wallet 6: 
    {, ""}: 100000000
Wallet 7: 
    {, ""}: 100000000
Wallet 8: 
    {, ""}: 100000000
Wallet 9: 
    {, ""}: 100000000
Wallet 10: 
    {, ""}: 100000000
```

- En estas trazas también aparecen los mensajes del código de la donación y también podemos incluir nuestros propios mensajes.
    > Slot 00021: *** USER LOG: reached Slot {getSlot = 21}


# Contract Monad
- La definición es la siguiente:
    > Contract w s e a
    - Tiene cuatro parámetros (_type parameters_) _w_, _s_, _e_ y _a_. Vamos a ver que significan: 
        - _w_: Permite a la mónada escribir mensajes de tipo _w_ (como en _Writer_), pero el propósito real es pasar información entre contratos y al exterior. Los datos en _w_ son visibles desde el exterior.
        - _e_: Es el tipo de mensajes de error ( como _Either_)
        - _s_: Parece que son los _endpoints_ disponibles dentro de este contrato (ej: _give_  y _grab_ en el ejemplo de la donación - Vesting.hs -)
        - _a_: Es el tipo del resultado.


- Ejemplo: Contract.hs
    > myContract1 :: Contract () Empty Text ()
    - _w_: (): No vamos a escribir ningún mensaje de error.
    - _s_: _Empty_ (esto es un tipo de datos): no hay endpoints
    - _e_: _Text_. Es un tipo de datos más eficiente que _String_ y es mejor opción para los mensajes de error
    - _a_: (). El contrato no devuelve nada.
    
    > myContract1 = Contract.logInfo @String "Hello from the contract"
    - Este contrato solo escribe un mensaje.

- Ampliación: Lanzar una excepción, es decir, el proceso se para y emite un mensaje de error.
    > Las excepciones se pueden capturar también.
    ```haskell
    myContract1 :: Contract () Empty Text ()
    myContract1 = do
        void $ Contract.throwError "BOOM!"
        Contract.logInfo @String "hello from the contract"
    ```
    - (): unity: solo tiene un valor
    - Void: void: no tiene valor.
- Capturar una excepción:
```haskell
    myContract2 :: Contract () Empty Void ()
    myContract2 = Contract.handleError
        (\err -> Contract.logError $ "caught: " ++ unpack err)
        myContract1
```
   - > Al capturar la excepción el contrato no se para.
- Endpoints
    ```haskell
    type MySchema = Endpoint "foo" Int .\/ Endpoint "bar" String

    myContract3 :: Contract () MySchema Text ()
    myContract3 = do
        n <- endpoint @"foo"
        Contract.logInfo n
        s <- endpoint @"bar"
        Contract.logInfo s

    myTrace3 :: EmulatorTrace ()
    myTrace3 = do
        h <- activateContractWallet (Wallet 1) myContract3
        callEndpoint @"foo" h 42
        callEndpoint @"bar" h "Haskell"

    test3 :: IO ()
    test3 = runEmulatorTraceIO myTrace3
    ```
    - _endpoint foo_ bloquea la ejecución hasta que se introduzca el dato que requiere como entrada.

- Contrato con _w_ (tipo de dato para mensajes de registro)
    ```haskell
    myContract4 :: Contract [Int] Empty Text ()
    myContract4 = do
        void $ Contract.waitNSlots 10
        tell [1]
        void $ Contract.waitNSlots 10
        tell [2]
        void $ Contract.waitNSlots 10

    myTrace4 :: EmulatorTrace ()
    myTrace4 = do
        h <- activateContractWallet (Wallet 1) myContract4

        void $ Emulator.waitNSlots 5
        xs <- observableState h
        Extras.logInfo $ show xs

        void $ Emulator.waitNSlots 10
        ys <- observableState h
        Extras.logInfo $ show ys

        void $ Emulator.waitNSlots 10
        zs <- observableState h
        Extras.logInfo $ show zs

    test4 :: IO ()
    test4 = runEmulatorTraceIO myTrace4
    ```

# Ejercicio
- Codificar las trazas de ejecución
- Capturar la excepción si no hay fondos.

