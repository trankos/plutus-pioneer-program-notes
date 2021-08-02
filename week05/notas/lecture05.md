Clase 05 [Lecture05](https://www.youtube.com/watch?v=SsaVjSsPPcg)

# Introducción
- Esta clase versará sobre como soporta los _tokens_ (_native tokens_) **Cardano**, como se acuñan (_minting_) y como se funden (_burnt_).
- Por _native tokens_ se entienden activos diferentes de ADA, es decir, vamos a ver como crear otras monedas distintas de ADA cuya operativa (transacciones, contratos, libros de cuentas) pueda gestionarse en la red de Cardano.
- Pero antes de tratar este tema, vamos a explicar el concepto de _valor_ en **Cardano**.

# Valor
- Ya se trato el modelo UTXO, EUTXO y el concepto de _Datum_ y, en todos los ejemplos que hemos visto, las transacciones contenían un valor en ADA o Lovelace, excepto en el ejemplo del contrato de subasta, donde el activo a subastar era un _NFT_ (_non fungible token_)

## Tipos de datos
- Los tipos relevantes están definidos en [Value.hs](https://playground.plutus.iohkdev.io/tutorial/haddock/plutus-ledger-api/html/Plutus-V1-Ledger-Value.html) y en [Ada.hs](https://github.com/input-output-hk/plutus/blob/master/plutus-ledger-api/src/Plutus/V1/Ledger/Ada.hs)

- Un valor, _Value_, define la cantidad de un _asset_, y un _asset_, se identifica por un símbolo (_CurrencySymbol_), por un nombre (_TokenName_) y por su cantidad.
```
 import Plutus.V1.Ledger.A
Plutus.V1.Ledger.Ada      Plutus.V1.Ledger.Address  Plutus.V1.Ledger.Api
Prelude Week04.Homework> import Plutus.V1.Ledger.Value 
Prelude Plutus.V1.Ledger.Value Week04.Homework> import Plutus.V1.Ledger.Value
Prelude Plutus.V1.Ledger.Value Week04.Homework> import Plutus.V1.Ledger.Ada
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> :set -XOverloadedStrings 
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> :t adaSymbol
adaSymbol :: CurrencySymbol
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> adaSymbol

Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> :t adaToken
adaToken :: TokenName
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> adaToken
""
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> :t lo
log              logBase          lookup           lovelaceOf       lovelaceValueOf
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> :t lovelaceValueOf 
lovelaceValueOf :: Integer -> Value
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> lovelaceValueOf 123
Value (Map [(,Map [("",123)])])
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> lovelaceValueOf 123 <> lovelaceValueOf 300
Value (Map [(,Map [("",423)])])
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> :t singleton
singleton :: CurrencySymbol -> TokenName -> Integer -> Value
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> singleton "a8ff" "PACO" 7
Value (Map [(a8ff,Map [("PACO",7)])])
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> :i singleton
singleton :: CurrencySymbol -> TokenName -> Integer -> Value
  	-- Defined in ‘Plutus.V1.Ledger.Value’
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> singleton "a8ff" "PACO" 7 <> lovelaceValueOf 34 <> singleton "a8ff" "XYZ" 34
Value (Map [(,Map [("",34)]),(a8ff,Map [("PACO",7),("XYZ",34)])])
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> let v = singleton "a8ff" "PACO" 7 <> lovelaceValueOf 34 <> singleton "a8ff" "XYZ" 34
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> valueOf v "a8ff" "XYZ"
34
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> valueOf v "a8ff" "xyz"
0
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> :t flattenValue 
flattenValue :: Value -> [(CurrencySymbol, TokenName, Integer)]
Prelude Plutus.V1.Ledger.Value Plutus.V1.Ledger.Ada Week04.Homework> flattenValue  v
[(a8ff,"PACO",7),(a8ff,"XYZ",34),(,"",34)]
```
- Regla: 
    > Una transacción no puede crear o destruir _tokens_, exceptuando las comisiones. Las comisiones no dependen del valor de la transacción sino del tamaño, en bytes y de los _scripts_ de validación, de su memoria y del número de pasos (supongo que se refiere al tiempo de ejecución, cuantas más líneas de código más pasos y más tiempo de ejecución, bueno esto no siempre es cierto)

- Por tanto es necesario fijar un política de acuñado (_minting policy_) y por eso es necesario este tipo de datos _Value_.
- Como hemos visto, _CurrencySymbol_, es un número hexadecimal, este número es el _hash_ de un script que define esta política (acuñar, fundir). Este script está incluido en la transacción y decide si una transacción tiene derecho a acuñar o a fundir _tokens_.
    - Supongo que se ejecutará siempre, como ocurre con el cálculo de comisiones (que acuñan moneda)

- Como hemos visto, ADA no tienen asociado ningún _script_, por lo que no es posible acuñar o fundir ADA. Todos los ADA que existen provienen de la transacción original _genesis transaction_.
> ¿Cuántos ADA hay circulando? En este momento unos 32000 M y el máximo será 41000 M

# Script de Política de Acuñado (I)

- UTXO : _Datum_, _Redeemer_, _ScriptContext_
    - _ScriptContext_: Campo _ScriptPurpose_: Uno de los propósitos es _Minting_. Este campo se rellena con el _CurrencySymbol_, que nos lleva al script de acuñado.
        - _TxInfo_ es la transacción. Esta tiene un campo _txInfoForge_ que contiene un _Value_. Si contiene un valor distinto de cero, se acuña (positivo), o se destruye (negativo). _Value_ puede tener _varias monedas, recordemos que es un diccionario. 
        - O sea que si _txInfoForge_ es distinto de cero se ejecuta el script de acuñado.
- Este script de acuñado tiene parámetros similares a los script de validación, _Redeemer_ y _ScriptContext_, no recibe el _Datum_. Este tiene sentido puesto que no le interesan las UTXO (¿?).
- Vamos a ver ejemplo: [Free.hs](../code/Free.hs)

- En este ejemplo se define una política de acuñado libre, es decir, cualquier transacción puede acuñar moneda.
- El _endpoint_ **mint** crea una transacción que ejecuta el script de acuñado con dos parámetros, la moneda y la cantidad.
- El script se prueba con una simulación que utiliza dos monederos y genera transacciones de acuñado (creando y destruyendo moneda)
    - En el balance final se aprecia que tiene dos entradas:
        - Una para ADA, donde se aprecia el cobro de las comisiones
        - Una para la moneda creada, _ABC_, con el resultado del acuñado.
```
Slot 00000: TxnValidate 0636250aef275497b4f3807d661a299e34e53e5ad3bc1110e43d1f3420bc8fae
Slot 00000: SlotAdd Slot 1
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Contract instance started
Slot 00001: 00000000-0000-4000-8000-000000000001 {Contract instance for wallet 2}:
  Contract instance started
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("mpAmount",Number 555.0),("mpTokenName",Object (fromList [("unTokenName",String "ABC")]))]))])]),("tag",String "ExposeEndpointResp")])
Slot 00001: W1: TxSubmit: 5656771f82f49ab4910778c2b289ccde6fe22577428effa17c7099086259cb96
Slot 00001: 00000000-0000-4000-8000-000000000001 {Contract instance for wallet 2}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("mpAmount",Number 444.0),("mpTokenName",Object (fromList [("unTokenName",String "ABC")]))]))])]),("tag",String "ExposeEndpointResp")])
Slot 00001: W2: TxSubmit: 30537b347bf6a6e1ecfc9ded6c61b5dbeabbf9bbcb0b6353682270c0f230a1be
Slot 00001: TxnValidate 30537b347bf6a6e1ecfc9ded6c61b5dbeabbf9bbcb0b6353682270c0f230a1be
Slot 00001: TxnValidate 5656771f82f49ab4910778c2b289ccde6fe22577428effa17c7099086259cb96
Slot 00001: SlotAdd Slot 2
Slot 00002: *** CONTRACT LOG: "forged Value (Map [(94e87e7456582edf7c8504a2352802450013a36ee9e5f2855d73db3e,Map [(\"ABC\",555)])])"
Slot 00002: *** CONTRACT LOG: "forged Value (Map [(94e87e7456582edf7c8504a2352802450013a36ee9e5f2855d73db3e,Map [(\"ABC\",444)])])"
Slot 00002: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("mpAmount",Number (-222.0)),("mpTokenName",Object (fromList [("unTokenName",String "ABC")]))]))])]),("tag",String "ExposeEndpointResp")])
Slot 00002: W1: TxSubmit: 4757b360969531263939c048673fac9dbff3745d9af75c9ffda6e16ae4f4ab28
Slot 00002: TxnValidate 4757b360969531263939c048673fac9dbff3745d9af75c9ffda6e16ae4f4ab28
Slot 00002: SlotAdd Slot 3
Slot 00003: *** CONTRACT LOG: "forged Value (Map [(94e87e7456582edf7c8504a2352802450013a36ee9e5f2855d73db3e,Map [(\"ABC\",-222)])])"
Slot 00003: SlotAdd Slot 4
Final balances
Wallet 1: 
    {, ""}: 99983946
    {94e87e7456582edf7c8504a2352802450013a36ee9e5f2855d73db3e, "ABC"}: 333
Wallet 2: 
    {94e87e7456582edf7c8504a2352802450013a36ee9e5f2855d73db3e, "ABC"}: 444
    {, ""}: 99991973
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

# Script de Política de acuñado (II)
- Vamos a analizar un ejemplo más realista, en el que se introducen condiciones como que las transacciones estén firmadas con una firma determinada, es decir, el acuñado o el fundido solo pueden realizarlo los dueños de ciertas firmas.
- Esta implementación solo permite ejecutar el acuñado si la operación se realiza con la misma firma del contrato: [Signed.hs](../code/Signed.hs)

> fmap ( + 1) [1,2,3] es equivalente a (+1) <$> [1, 2, 3]

> pkh <- pubKeyHash <$> Contract.ownPubKey

- El resultado de la ejecución del test debería ser el siguiente:

```
lot 00000: TxnValidate 0636250aef275497b4f3807d661a299e34e53e5ad3bc1110e43d1f3420bc8fae
Slot 00000: SlotAdd Slot 1
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Contract instance started
Slot 00001: 00000000-0000-4000-8000-000000000001 {Contract instance for wallet 2}:
  Contract instance started
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("mpAmount",Number 555.0),("mpTokenName",Object (fromList [("unTokenName",String "ABC")]))]))])]),("tag",String "ExposeEndpointResp")])
Slot 00001: W1: TxSubmit: 1dc3391b8129b480c2ff46579ab1ffc92a443b85f9d6f9e51e611c52169558d1
Slot 00001: 00000000-0000-4000-8000-000000000001 {Contract instance for wallet 2}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("mpAmount",Number 444.0),("mpTokenName",Object (fromList [("unTokenName",String "ABC")]))]))])]),("tag",String "ExposeEndpointResp")])
Slot 00001: W2: TxSubmit: 771ba2f60e84ed9739e433b55e26a24e9e94595951442fde8d2d507667e844f9
Slot 00001: TxnValidate 771ba2f60e84ed9739e433b55e26a24e9e94595951442fde8d2d507667e844f9
Slot 00001: TxnValidate 1dc3391b8129b480c2ff46579ab1ffc92a443b85f9d6f9e51e611c52169558d1
Slot 00001: SlotAdd Slot 2
Slot 00002: *** CONTRACT LOG: "forged Value (Map [(c68b1c06a42e7a809eb8b467d880d7123448d8b574b5c90858ed80f5,Map [(\"ABC\",555)])])"
Slot 00002: *** CONTRACT LOG: "forged Value (Map [(77f13ca4b514a4b140cb81dc191d4f58409a173832fb06c4ae64b591,Map [(\"ABC\",444)])])"
Slot 00002: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("mpAmount",Number (-222.0)),("mpTokenName",Object (fromList [("unTokenName",String "ABC")]))]))])]),("tag",String "ExposeEndpointResp")])
Slot 00002: W1: TxSubmit: b18ccbcd6d91615c65e9129c3c46214b9d11f60467b5e38c6370d31e461afeaa
Slot 00002: TxnValidate b18ccbcd6d91615c65e9129c3c46214b9d11f60467b5e38c6370d31e461afeaa
Slot 00002: SlotAdd Slot 3
Slot 00003: *** CONTRACT LOG: "forged Value (Map [(c68b1c06a42e7a809eb8b467d880d7123448d8b574b5c90858ed80f5,Map [(\"ABC\",-222)])])"
Slot 00003: SlotAdd Slot 4
Final balances
Wallet 1: 
    {, ""}: 99983448
    {c68b1c06a42e7a809eb8b467d880d7123448d8b574b5c90858ed80f5, "ABC"}: 333
Wallet 2: 
    {77f13ca4b514a4b140cb81dc191d4f58409a173832fb06c4ae64b591, "ABC"}: 444
    {, ""}: 99991724
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
- El resultado es el mismo que en el caso anterior excepto que tenemos **DOS** contratos, dos _tokens_, diferentes (aunque se llaman igual _ABC_). Esto es porque hemos introducido en el contrato la firma del que lo genera, por tanto, los tokens son diferentes.
    - Wallet 1 solo puede acuñar monedas asociadas a _c68b1c06a42e7a809eb8b467d880d7123448d8b574b5c90858ed80f5_ y Wallet 2 solo puede acuñar monedas asociadas a _77f13ca4b514a4b140cb81dc191d4f58409a173832fb06c4ae64b591_.
    - Este modelo es el que utilizan los bancos centrales de una moneda: solo ese banco puede crear moneda (el BCE acuña el Euro)


# NFT (Non Fungible Tokens)
> Un NFT es un _token_ que solo puede existir una vez, es decir, que es ÚNICO.

- La idea es que solo puede existir una transacción de acuñado. ¿Cómo conseguirlo en Cardano?
- En la versión actual de Cardano no es posible conseguir este objetivo (habría que acuñar y luego comprobar en la BlockChain que no se ha acuñado de nuevo).
- La clave está en que es necesario definir en Cardano algo que sea único. Bien, las transacciones de Cardano, UTXO, son únicas por definición: una transacción se consume en una operación y, esa misma transacción no puede ser consumida de nuevo nunca más.
- Es evidente que pueden existir dos transacciónes idénticas en lo que respecta a la _dirección_ y _valor_ pero **NUNCA** tendrán el mismo **IDENTIFICADOR**.
- La solución será utilizar como parámetro de entrada del script de acuñado un identificador de la UTXO.

## Ejemplo
- [NFT](../code/NFT.hs)

```
Slot 00000: TxnValidate 0636250aef275497b4f3807d661a299e34e53e5ad3bc1110e43d1f3420bc8fae
Slot 00000: SlotAdd Slot 1
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Contract instance started
Slot 00001: 00000000-0000-4000-8000-000000000001 {Contract instance for wallet 2}:
  Contract instance started
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("unTokenName",String "ABC")]))])]),("tag",String "ExposeEndpointResp")])
Slot 00001: W1: TxSubmit: ca3fbb3648549681ac2a8783b4642f81e2c7d490dbd87d5085511334bb0cf6e0
Slot 00001: 00000000-0000-4000-8000-000000000001 {Contract instance for wallet 2}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("unTokenName",String "ABC")]))])]),("tag",String "ExposeEndpointResp")])
Slot 00001: W2: TxSubmit: 3d8529ec6d95f3a6eb1967f0e7af84e4aff2c60e5d7e2ad32a441a28c996f744
Slot 00001: TxnValidate 3d8529ec6d95f3a6eb1967f0e7af84e4aff2c60e5d7e2ad32a441a28c996f744
Slot 00001: TxnValidate ca3fbb3648549681ac2a8783b4642f81e2c7d490dbd87d5085511334bb0cf6e0
Slot 00001: SlotAdd Slot 2
Slot 00002: *** CONTRACT LOG: "forged Value (Map [(9d0e665c48ada452046b1338512d8ce6549bef62ddfb925fd34f9b57,Map [(\"ABC\",1)])])"
Slot 00002: *** CONTRACT LOG: "forged Value (Map [(06d6ce84988724692e902a6e01a9f8a1fd5de9781318b2a658153734,Map [(\"ABC\",1)])])"
Slot 00002: SlotAdd Slot 3
Final balances
Wallet 1: 
    {9d0e665c48ada452046b1338512d8ce6549bef62ddfb925fd34f9b57, "ABC"}: 1
    {, ""}: 99991202
Wallet 2: 
    {06d6ce84988724692e902a6e01a9f8a1fd5de9781318b2a658153734, "ABC"}: 1
    {, ""}: 99991202
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

# Ejercicio 1
- Implementar una política de acuñado (_on chain_) con dos parámetros:
    - Clave: solo esta clave puede acuñar.
    - Fecha límite: Fecha hasta la que se puede acuñar
- El resultado debe ser similar a este:

```
Prelude Week05.Homework1> test
Slot 00000: TxnValidate 0636250aef275497b4f3807d661a299e34e53e5ad3bc1110e43d1f3420bc8fae
Slot 00000: SlotAdd Slot 1
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Contract instance started
Slot 00001: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("mpAmount",Number 555.0),("mpDeadline",Number 1.596059101e12),("mpTokenName",Object (fromList [("unTokenName",String "ABC")]))]))])]),("tag",String "ExposeEndpointResp")])
Slot 00001: W1: TxSubmit: 7e6f21265f6223e43d413e57f6bbb9f10015394694b47d8579902d73ca83d3d3
Slot 00001: TxnValidate 7e6f21265f6223e43d413e57f6bbb9f10015394694b47d8579902d73ca83d3d3
Slot 00001: SlotAdd Slot 2
Slot 00002: *** CONTRACT LOG: "forged Value (Map [(0fd93a1ae5f65673fc11d4b27dd133f7b356f24942a9f34b6701c232,Map [(\"ABC\",555)])])"
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
Slot 00016: 00000000-0000-4000-8000-000000000000 {Contract instance for wallet 1}:
  Receive endpoint call on 'mint' for Object (fromList [("contents",Array [Object (fromList [("getEndpointDescription",String "mint")]),Object (fromList [("unEndpointValue",Object (fromList [("mpAmount",Number 555.0),("mpDeadline",Number 1.596059101e12),("mpTokenName",Object (fromList [("unTokenName",String "ABC")]))]))])]),("tag",String "ExposeEndpointResp")])
Slot 00016: *** CONTRACT LOG: "deadline passed"
Slot 00016: SlotAdd Slot 17
Slot 00017: SlotAdd Slot 18
Final balances
Wallet 1: 
    {0fd93a1ae5f65673fc11d4b27dd133f7b356f24942a9f34b6701c232, "ABC"}: 555
    {, ""}: 99990465
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

```
- La solución propuesta realiza validaciones _off-chain_, entre ellas la de la fecha límite, por lo que la validación _on-chain_ de la fecha no se ejecuta puesto que la transacción de acuñado nunca se envía.


# Ejercicio 2
- Implementar una política de acuñado para un NFT y sin nombre de token (EmptyString) (Igual que ADA, que no tiene...)

- Solución propuesta es muy sencilla [Solution2.hs](../code/Solutin2.hs): se basa en [NFT](../code/NFT.hs) y la única variaciónes introducir como constante el nombre del token:

```haskell
{-# INLINABLE tn #-}
tn :: TokenName
tn = TokenName emptyByteString
```
- Y eliminar el parámetro tn del resto de funciones: _policy_ , _curSymbol_ y _mint_ y en las respectivas llamadas.





