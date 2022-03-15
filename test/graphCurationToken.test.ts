import { expect } from 'chai'
import { constants, utils, BytesLike, BigNumber, Signature } from 'ethers'
import { eip712 } from '@graphprotocol/common-ts/dist/attestations'

import { GraphToken } from '../build/types/GraphToken'
import { GraphCurationToken } from '../build/types/GraphCurationToken'

import * as deployment from './lib/deployment'
import { getAccounts, getChainID, toBN, toGRT, Account } from './lib/testHelpers'

const { AddressZero, MaxUint256 } = constants
const { keccak256, SigningKey } = utils

describe('GraphCurationToken', () => {
  let me: Account
  let other: Account
  let governor: Account

  let grt: GraphToken
  let gcs: GraphCurationToken

  before(async function () {
    ;[me, other, governor] = await getAccounts()
  })

  beforeEach(async function () {
    // Deploy graph token and GCS
    grt = await deployment.deployGRT(governor.signer)
    gcs = await deployment.deployGCS(governor.signer)
    await gcs.connect(governor.signer).initialize(governor.address)

    // Mint some tokens
    const tokens = toGRT('10000')
    await grt.connect(governor.signer).mint(me.address, tokens)
    await grt.connect(governor.signer).mint(other.address, tokens)
  })

  describe('mint', async function () {
    context('if NOT governor', function () {
      it('should revert on mint', async function () {
        const tokensToMint = toGRT('100')
        const tokensToDeposit = toGRT('10')
        const tx = gcs.connect(me.signer).mint(me.address, tokensToMint, tokensToDeposit)
        await expect(tx).revertedWith('Only Governor can call')
      })
    })

    context('if governor', function () {
      it('should mint saving the correct deposit', async function () {
        const tokensToMint = toGRT('100')
        const tokensToDeposit = toGRT('10')

        const beforeTokens = await gcs.balanceOf(me.address)
        const beforeDeposits = await gcs.deposits(me.address)

        const tx = gcs.connect(governor.signer).mint(me.address, tokensToMint, tokensToDeposit)
        await expect(tx).emit(gcs, 'Transfer').withArgs(AddressZero, me.address, tokensToMint)

        const afterTokens = await gcs.balanceOf(me.address)
        const afterDeposits = await gcs.deposits(me.address)
        expect(afterTokens).eq(beforeTokens.add(tokensToMint))
        expect(afterDeposits).eq(beforeDeposits.add(tokensToDeposit))
      })
    })
  })

  describe('burn', async function () {
    const tokensPreMinted = toGRT('100')
    const tokensPreDeposited = toGRT('10')

    beforeEach(async function () {
      await gcs.connect(governor.signer).mint(me.address, tokensPreMinted, tokensPreDeposited)
    })

    context('if NOT governor', function () {
      it('should revert on burn', async function () {
        const tokensToBurn = toGRT('100')
        const tx = gcs.connect(me.signer).burnFrom(me.address, tokensToBurn)
        await expect(tx).revertedWith('Only Governor can call')
      })
    })

    context('if governor', function () {
      it('should burn fully removing all deposits', async function () {
        const beforeTokens = await gcs.balanceOf(me.address)
        const beforeDeposits = await gcs.deposits(me.address)

        const tx = gcs.connect(governor.signer).burnFrom(me.address, tokensPreMinted)
        await expect(tx).emit(gcs, 'Transfer').withArgs(me.address, AddressZero, tokensPreMinted)

        const afterTokens = await gcs.balanceOf(me.address)
        const afterDeposits = await gcs.deposits(me.address)
        expect(afterTokens).eq(beforeTokens.sub(tokensPreMinted))
        expect(afterDeposits).eq(beforeDeposits.sub(tokensPreDeposited))
      })

      it('should burn partially removing the proportional deposit', async function () {
        const beforeTokens = await gcs.balanceOf(me.address)
        const beforeDeposits = await gcs.deposits(me.address)

        const tokensToBurn = toGRT('50')
        const depositDeltaForBurning = await gcs.getDepositDelta(me.address, tokensToBurn)

        const tx = gcs.connect(governor.signer).burnFrom(me.address, tokensToBurn)
        await expect(tx).emit(gcs, 'Transfer').withArgs(me.address, AddressZero, tokensToBurn)

        const afterTokens = await gcs.balanceOf(me.address)
        const afterDeposits = await gcs.deposits(me.address)
        expect(afterTokens).eq(beforeTokens.sub(tokensToBurn))
        expect(afterDeposits).eq(beforeDeposits.sub(depositDeltaForBurning))
        expect(afterDeposits).gt(0)
      })
    })
  })

  describe('transfer', async function () {
    const tokensPreMinted = toGRT('100')
    const tokensPreDeposited = toGRT('10')

    beforeEach(async function () {
      await gcs.connect(governor.signer).mint(me.address, tokensPreMinted, tokensPreDeposited)
      await gcs.connect(governor.signer).mint(other.address, tokensPreMinted, tokensPreDeposited)
    })

    it('should transfer fully correctly also moving the deposit', async function () {
      const beforeTokensMe = await gcs.balanceOf(me.address)
      const beforeDepositsMe = await gcs.deposits(me.address)
      const beforeTokensOther = await gcs.balanceOf(other.address)
      const beforeDepositsOther = await gcs.deposits(other.address)

      const tx = gcs.connect(me.signer).transfer(other.address, tokensPreMinted)
      await expect(tx).emit(gcs, 'Transfer').withArgs(me.address, other.address, tokensPreMinted)

      const afterTokensMe = await gcs.balanceOf(me.address)
      const afterDepositsMe = await gcs.deposits(me.address)
      const afterTokensOther = await gcs.balanceOf(other.address)
      const afterDepositsOther = await gcs.deposits(other.address)

      expect(afterTokensMe).eq(beforeTokensMe.sub(tokensPreMinted))
      expect(afterTokensOther).eq(beforeTokensOther.add(tokensPreMinted))

      expect(afterDepositsMe).eq(beforeDepositsMe.sub(tokensPreDeposited))
      expect(afterDepositsOther).eq(beforeDepositsOther.add(tokensPreDeposited))
    })

    it('should burn partially removing the proportional deposit', async function () {
      const beforeTokensMe = await gcs.balanceOf(me.address)
      const beforeDepositsMe = await gcs.deposits(me.address)
      const beforeTokensOther = await gcs.balanceOf(other.address)
      const beforeDepositsOther = await gcs.deposits(other.address)

      const tokensToTransfer = toGRT('50')
      const depositDeltaForTransfer = await gcs.getDepositDelta(me.address, tokensToTransfer)
      const tx = gcs.connect(me.signer).transfer(other.address, tokensToTransfer)
      await expect(tx).emit(gcs, 'Transfer').withArgs(me.address, other.address, tokensToTransfer)

      const afterTokensMe = await gcs.balanceOf(me.address)
      const afterDepositsMe = await gcs.deposits(me.address)
      const afterTokensOther = await gcs.balanceOf(other.address)
      const afterDepositsOther = await gcs.deposits(other.address)

      expect(afterTokensMe).eq(beforeTokensMe.sub(tokensToTransfer))
      expect(afterTokensOther).eq(beforeTokensOther.add(tokensToTransfer))

      expect(afterDepositsMe).eq(beforeDepositsMe.sub(depositDeltaForTransfer))
      expect(afterDepositsOther).eq(beforeDepositsOther.add(depositDeltaForTransfer))
    })
  })
})
