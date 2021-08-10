
# Regla Nº1

**ANYBODY can send ANYTHING to ANY address. Validation only happens when you try to SPEND a UTxO, NOT when you CREATE one. It's important to keep this in mind.**

- Esta regla viene a ser lo mismo que decir que en un servicio hay que validar siempre los datos de entrada. 

# Block & Slot
- Una explicación de como se generan los bloques en la red de Cardano:

Slot time in Cardano is one second. Each second, there will be a "lottery" to determine a slot leader, who then has the right to produce a block. HOWEVER, there will only be a winner of the lottery with a probability of 5%, so on average, only every 20 seconds a slot leader will be elected and produce a block. So block time on Cardano is 20s.
In the playground (and the emulator), there's one simulated block every slot/second. That's why in my examples, I have such short wait times.
(However, note that in the Playground, there are two different types of waits - you can wait for a specific slot or wait until a certain number of blocks have been produced.)


# Una conversación sobre una aplicación práctica
[Aquí](https://www.youtube.com/watch?v=24SHPHEc3zo)

Lars Brünjes
hace 1 semana
Can you elaborate a bit on your use-case? - Keep in mind that Plutus is brand new, so nobody has implemented an oracle yet.



Prompt
Prompt
hace 1 semana (editado)
 @Lars Brünjes  sure, my client wants to tokenize the Kwh that he buys in europe at wholesale price (making the bill for people much cheaper) so there’s a Broker app and API to buy and sell selecteicity at wholesale price that vary in price (€),and the unit is Kw/1h. That kWh can be store in wallets (native token) and you can pay the electricity bill with your token too if you contract his company in europe.
So, when you buy KWH token the price needs to be reconciliated.

use case: people can buy during the year the electricity, at much reduced price as there’s no intermediary, when it’s cheaper and spend it the whole year. I think is a stable coin pegged to an external asset that every day changes the price (I think at 9pm) after an auction.

Appreciate your answer!🙏🏻

1


Lars Brünjes
Lars Brünjes
hace 1 semana
 @Prompt  I'm not sure I understand completely, but isn't that very similar to my example from the lecture? Except that I am using USD per ADA, and you are interested in ADA per KW/h?
So wouldn't the same simple approach work: Some trusted partner, like the auctioneer, updates the oracle every morning at 9:00?

Or am I missing something?



Prompt
Prompt
hace 1 semana
 @Lars Brünjes  I think it's very close. The unique point missing for our use case, that we can avoid for now is; if the auction at 9pm doesn't fulfill the amount, either you reconcíliate giving more or less, with a kind of elasticity. But let's avoid dig deeper into this technicalities, can be solve in the server side.

Questions:
1. When you mention mint NFTs in this example, we are talking about Native Assets, right? In this example you use USDT as "NFT", right?
2. it is a good strategy that the minting contract only mints the amount of the tokens transacted? As far I know USDT and other mint a bunch of coins expecting a lot of transactions in advance, however I'm not sure why.
3. Does Cardano blockchain has the ability to update the smart-contracts keeping the same address? Or it's not recommended? Sorry if this question is answer somewhere and I couldn't research properly.
4. You mentioned that getting the price from coinmarketcap every 5s might be too much as blocks are written every 20 seconds. Does it mean, for the moment, we cannot do things in Cardano with data that changes prices in less than 20 seconds? (is not my use case, just curiosity) 

I appreciate your time Lars, thanks a lot!



Lars Brünjes
Lars Brünjes
hace 1 semana
 @Prompt  
1. No, an NFT, by definition, only exists once. I use it to uniquely identify the oracle UTxO (because there could be other UTxO's at the same address). But yes, it is a native token. The USDT's in my example are just "there". They would have been minted earlier, but I don't care about how. They are NOT NFT's, because millions or billions of them can exist, not just one.

2. No, but I'm not doing that. All I'm minting is the NFT, which I need for "book keeping purposes", to identify the oracle.

3. Not directly. A UTxO can never change, only be spent. And if you change the validator, the address changes (because it's the hash of the validator). However, it IS possible to build "changebility" into a Plutus validator by using a trick, some extra level of indirection: The validator "delegates" validation to ANOTHER validator, which is specified in the datum of the UTxO. By changing that datum, you can change that second validator and hence validation logic.

4. That's right, time-resolution in Cardano is about 20 seconds. Still not bad compared to Bitcoin's ten minutes, and in the same ballpark as Ethereum's 15 seconds.



Prompt
Prompt
hace 1 semana
 @Lars Brünjes  I really appreciate your time Lars! I might be lost now :) I have 16 yeas of programming experience but I'm like a newbie with the blockchain :D
1.a Nowadays we need to create an NFT to identify the Oracle?
1.b When I was mentioning USDT as Native Asset is to compare with my KWH, I think in your example I swap the TokenName with KWH, my Native Asset, right?

2.a Let me rephrase, sorry if was confusing concepts... In order to have a pegged asset ADA/KWH, I'm asking if it's a good strategy mint coins expecting volume or mint coins before the transaction happens WHEN the I get from the Oracle the value. I personally believe that it's the correct way to do it, might be not possible to wait until the minting is finish or other technicalities that scape from my understanding. 
2.b In my use case the burning of KWH tokens will happen when you pay the electricity bill with your tokens (or reduce the invoice). Can you point me to a link or example where in the moment to send a transaction to a special wallet address tokens are burned? maybe this can be done in a better way like have like a cron task and burn all coins in a special wallet? So far I'm not sure how to execute an automated burn policy.

3. I think know how to do that might be really great, so developers have a way to have smart contracts always bug fixed or up-to-date.

4. I think in the next Cardano phase will be a way to create side chains, right? having even your Native Token to pay for the transactions (or this latest statement will happen in this phase also?)
