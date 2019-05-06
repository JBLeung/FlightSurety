
const BigNumber = require('bignumber.js')
const Test = require('../config/testConfig.js')

const CONSENSUS_THRESHOLD = 4;
const minFund = web3.utils.toWei('10', 'ether');  

contract('Flight Surety Tests', async (accounts) => {
  let config
  let contractAddress
  let firstAirlineAddress
  before('setup contract', async () => {
    config = await Test.Config(accounts)
    contractAddress = config.flightSuretyApp.address
    firstAirlineAddress = config.firstAirline
    await config.flightSuretyData.authorizeContracts(contractAddress)
  })

  /** ************************************************************************************* */
  /* Operations and Settings                                                              */
  /** ************************************************************************************* */

  it('(multiparty) has correct initial isOperational() value', async () => {
    // Get operating status
    const status = await config.flightSuretyData.isOperational.call()
    assert.equal(status, true, 'Incorrect initial operating status value')
  })

  it('(multiparty) can block access to setOperatingStatus() for non-Contract Owner account', async () => {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false
    try {
      await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] })
    } catch (e) {
      accessDenied = true
    }
    assert.equal(accessDenied, true, 'Access not restricted to Contract Owner')
  })

  it('(multiparty) can allow access to setOperatingStatus() for Contract Owner account', async () => {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false
    try {
      await config.flightSuretyData.setOperatingStatus(false)
    } catch (e) {
      accessDenied = true
    }
    assert.equal(accessDenied, false, 'Access not restricted to Contract Owner')
  })

  it('(multiparty) can block access to functions using requireIsOperational when operating status is false', async () => {
    await config.flightSuretyData.setOperatingStatus(false)

    let reverted = false
    try {
      await config.flightSurety.setTestingMode(true)
    } catch (e) {
      reverted = true
    }
    assert.equal(reverted, true, 'Access not blocked for requireIsOperational')

    // Set it back for other tests to work
    await config.flightSuretyData.setOperatingStatus(true)
  })

  it('(airline) 1st airline is registed', async () => {
    // ARRANGE
    // ACT
    const count = await config.flightSuretyData.getRegisteredAirlineCount({from: contractAddress})
    const isFirstAirlineRegistered = await config.flightSuretyData.checkAirlineIsRegisterd(firstAirlineAddress, {from: contractAddress})

    // ASSERT
    assert.equal(count, 1, "should be no registerd airline before 1st registered")
    assert.equal(isFirstAirlineRegistered, true, "1st airline did not register")
  })

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    // ARRANGE
    const newAirline = accounts[2]

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, {from: firstAirlineAddress})
    } catch (e) {
      // should be error
    }
    const result = await config.flightSuretyData.checkAirlineIsRegisterd.call(newAirline, {from: contractAddress})

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding")
  })

  it('(airline) pay fund for 1st airline', async () => {
    // ARRANGE
    // ACT
    const resultBefore = await config.flightSuretyData.checkAirlineIsPaidFund(firstAirlineAddress, {from: contractAddress})
    const isFirstAirlineRegistered = await config.flightSuretyData.checkAirlineIsRegisterd(firstAirlineAddress, {from: contractAddress})
    await config.flightSuretyApp.payFunding({from:firstAirlineAddress, value: minFund})
    const resultAfter = await config.flightSuretyData.checkAirlineIsPaidFund(firstAirlineAddress, {from: contractAddress})

    // ASSERT
    assert.equal(resultBefore, false, "Airline already is paid fund")
    assert.equal(isFirstAirlineRegistered, true, "1st airline did not register")
    assert.equal(resultAfter, true, "Canot pay fund for registered airline")
  })

  it('(airline) without Multiparty Consensus with registered airline less then CONSENSUS_THRESHOLD', async () => {
    // ARRANGE
    for(let index= 1 ; index < CONSENSUS_THRESHOLD + 1; index ++ ){
      // ACT
      const nextAirline = accounts[index];
      try{
        await config.flightSuretyApp.registerAirline(nextAirline, {from: firstAirlineAddress})
      } catch (e) {
        // will fail when index >= CONSENSUS_THRESHOLD
        // ASSERT
      }
      // ASSERT
      const nextRegisterResult = await config.flightSuretyData.checkAirlineIsRegisterd.call(nextAirline, {from: contractAddress})
      if(index < CONSENSUS_THRESHOLD){
        assert.equal(nextRegisterResult, true, `Fail to register ${index} airline`)
      }else{
        const isRegistering = await config.flightSuretyData.checkAirlineIsRegistering.call(nextAirline, {from: contractAddress})
        assert.equal(nextRegisterResult, false, `Fail to register ${index} airline`)
        assert.equal(isRegistering, true, `index > CONSENSUS_THRESHOLD should be registering`)
      }
    }
  })
  
  it('(airline) Multiparty Consensus is work on registering new airline', async () => {
    // ARRANGE
    const fourthAirlineAddress = accounts[4]
    // ACT
    const beforeIsNotRegistered = await config.flightSuretyData.checkAirlineIsRegisterd.call(fourthAirlineAddress, {from: contractAddress})
    const beforeIsRegistering = await config.flightSuretyData.checkAirlineIsRegistering.call(fourthAirlineAddress, {from: contractAddress})
    // ASSERT
    assert.equal(beforeIsNotRegistered, false, `4th airline is already registered`)
    assert.equal(beforeIsRegistering, true, `4th airline is not registering`)

    // ACT
    await config.flightSuretyApp.registerAirline(fourthAirlineAddress, {from: firstAirlineAddress})
    const afterRegisterResult = await config.flightSuretyData.checkAirlineIsRegisterd.call(fourthAirlineAddress, {from: contractAddress})
    const afterIsRegistering = await config.flightSuretyData.checkAirlineIsRegistering.call(fourthAirlineAddress, {from: contractAddress})
    // ASSERT
    assert.equal(afterRegisterResult, true, `Fail to register 4th airline`)
    assert.equal(afterIsRegistering, false, `4th airline should be registering done`)

  })
  // it('', async () => {
  //   // ARRANGE
  //   // ACT
  //   // ASSERT
  // })

})
