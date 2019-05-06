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

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) private authorizedContracts;

    uint256 private numberOfRegisteredAirlines = 0;
    mapping(address => Airline) private airlines;
    mapping(address => uint256) private registeringAirlines;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event Log(string text, uint number);

    event AirlineRegistered(address newAirline);

    /********************************************************************************************/
    /*                                          CONSTRUCTOR                                     */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(address firstAirline) public {
        contractOwner = msg.sender;

        //init for first airline
        _registerAirline(firstAirline);
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

    modifier isAuthorizeAirline(address airlineAddress){
        require(
            _airlineIsRegistered(airlineAddress) && _airlineIsPaidFund(airlineAddress),
            "Caller is not authorized, not registed / not paid fund"
        );
        _;
    }

    modifier isAirline(address airlineAddress){
        require(airlines[airlineAddress].isRegistered, "Caller is not airline");
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
    function registerAirline(address newAirlineAddress, address callerAirline)
    external requireAuthorizeContracts requireIsOperational isAuthorizeAirline(callerAirline)
    {
        _registerAirline(newAirlineAddress);
    }

    function voteForNewAirline(address airlineAddressToVote, address callerAirline)
    external requireAuthorizeContracts requireIsOperational isAuthorizeAirline(callerAirline)
    returns(uint256 votes)
    {
        airlines[callerAirline].votedForAirlines[airlineAddressToVote] = true;
        registeringAirlines[airlineAddressToVote] = registeringAirlines[airlineAddressToVote].add(1);

        votes = registeringAirlines[airlineAddressToVote];
    }

    function getRegisteredAirlineCount() external view returns(uint256 count) {
        count = numberOfRegisteredAirlines;
    }

    function checkAirlineIsRegisterd(address airlineAddress) external view requireAuthorizeContracts requireIsOperational returns(bool) {
        return _airlineIsRegistered(airlineAddress);
    }

    function checkAirlineIsPaidFund(address airlineAddress) external view requireAuthorizeContracts requireIsOperational returns(bool) {
        return _airlineIsPaidFund(airlineAddress);
    }
    
    function checkAirlineIsRegistering(address airlineAddress) external view requireAuthorizeContracts requireIsOperational returns(bool) {
        return _airlineIsRegistering(airlineAddress);
    }

    function airlinePayFunding(uint joinFee, address callerAirline)
    external payable
    requireIsOperational requireAuthorizeContracts isAirline(callerAirline)
    {
        require(!airlines[callerAirline].hasPaidFund, "Calling airline has already paid their funds");
        // require(msg.value >= joinFee, "Not enough ether to pay");
        // uint256 amountToReturn = msg.value - joinFee;
        // callerAirline.transfer(amountToReturn);
        airlines[callerAirline].hasPaidFund = true;
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
        return (airlines[airlineAddress].isRegistered);
    }

    function _airlineIsPaidFund(address airlineAddress) private view requireAuthorizeContracts requireIsOperational returns(bool) {
        return (airlines[airlineAddress].hasPaidFund);
    }

    function _airlineIsRegistering(address airlineAddress) private view requireAuthorizeContracts requireIsOperational returns(bool) {
        return (registeringAirlines[airlineAddress] > 0);
    }

    function _registerAirline(address newAirlineAddress)
    private requireIsOperational
    {
        // accept the new register
        airlines[newAirlineAddress].isRegistered = true;
        numberOfRegisteredAirlines = numberOfRegisteredAirlines.add(1);
        voteDone(newAirlineAddress);
        emit AirlineRegistered(newAirlineAddress);
    }

    function voteDone(address airlineAddressToVote) private requireIsOperational {
        registeringAirlines[airlineAddressToVote] = 0;
    }

}