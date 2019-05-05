pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract FlightSuretyData {
    /********************************************************************************************/
    /*                                           LIBRARY                                        */
    /********************************************************************************************/

    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                        DATA STRUCT                                       */
    /********************************************************************************************/
    struct Airline {
        bool isRegistered;
        bool hasPaidFund;
        mapping(address => bool) votedForAirlines;
    }

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    uint256 constant JOIN_FEE = 10 ether;

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) private authorizedContracts;

    uint256 private numberOfRegisteredAirlines = 0;
    mapping(address => Airline) private airlines;
    mapping(address => uint256) private registeringAirlines;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address newAirline);

    /********************************************************************************************/
    /*                                          CONSTRUCTOR                                     */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public {
        contractOwner = msg.sender;

        // init for fist airline
        _registerAirline(msg.sender);
    }

    /********************************************************************************************/
    /*                                       FALLBACK FUNCTION                                  */
    /********************************************************************************************/

     /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        fund();
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizeContracts() {
        require(isAuthorizeContracts(msg.sender), "Is not authorize contract");
        _;
    }

    modifier isAuthorizeAirline(){
        require(_airlineIsRegistered(msg.sender), "Caller is not authorized, not registed / not paid fund");
        _;
    }


    /********************************************************************************************/
    /*                                       EXTERNAL FUNCTIONS                                 */
    /********************************************************************************************/

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */

    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /**
    * restrict data contract callers
    */
    function authorizeContracts(address caller) external requireContractOwner {
        authorizedContracts[caller] = true;
    }

    function unauthorizeContracts(address caller) external requireContractOwner {
        delete authorizedContracts[caller];
    }

    /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline(address newAirlineAddress)
    external requireAuthorizeContracts requireIsOperational isAuthorizeAirline
    {
        _registerAirline(newAirlineAddress);
    }

    function voteForNewAirline(address newAirlineAddress)
    external requireAuthorizeContracts requireIsOperational isAuthorizeAirline
    returns(uint256 votes)
    {
        airlines[msg.sender].votedForAirlines[newAirlineAddress] = true;
        registeringAirlines[newAirlineAddress] = registeringAirlines[newAirlineAddress].add(1);

        votes = registeringAirlines[newAirlineAddress];
    }

    function getRegisteredAirlineCount() external view returns(uint256 count) {
        count = numberOfRegisteredAirlines;
    }

    function checkAirlineIsRegisterd(address airlineAddress) external view requireAuthorizeContracts requireIsOperational returns(bool) {
        return _airlineIsRegistered(airlineAddress);
    }

    function airlinePayFunding() external payable requireIsOperational requireAuthorizeContracts {
        require(msg.value >= JOIN_FEE, "value is too low, price not met");
        require(airlines[msg.sender].isRegistered, "Caller is not a registered airline");
        require(!airlines[msg.sender].hasPaidFund, "Calling airline has already paid their funds");

        airlines[msg.sender].hasPaidFund = true;

        uint256 amountToReturn = msg.value - JOIN_FEE;
        msg.sender.transfer(amountToReturn);
    }

    /**
    * @dev Buy insurance for a flight
    *
    */
    function buy() external payable {
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees() external pure {
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay() external pure {
    }

    /********************************************************************************************/
    /*                                        PUBLIC FUNCTIONS                                  */
    /********************************************************************************************/

    function isAuthorizeContracts(address caller) public view returns(bool) {
        return authorizedContracts[caller] == true;
    }

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */

    function isOperational() public view returns(bool) {
        return operational;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund() public payable {
    }

    /********************************************************************************************/
    /*                                        INTERNAL FUNCTIONS                                */
    /********************************************************************************************/

    function getFlightKey(address airline, string memory flight, uint256 timestamp) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /********************************************************************************************/
    /*                                        PRIVATE FUNCTIONS                                */
    /********************************************************************************************/

    function _airlineIsRegistered(address airlineAddress) private view requireAuthorizeContracts requireIsOperational returns(bool) {
        return (airlines[airlineAddress].isRegistered && airlines[airlineAddress].hasPaidFund);
    }

    function _registerAirline(address newAirlineAddress)
    private  requireAuthorizeContracts requireIsOperational
    {
        // accept the new register
        airlines[newAirlineAddress].isRegistered = true;
        numberOfRegisteredAirlines = numberOfRegisteredAirlines.add(1);
        emit AirlineRegistered(newAirlineAddress);
    }

}

