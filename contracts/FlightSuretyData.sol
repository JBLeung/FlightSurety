pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract FlightSuretyData {
    /********************************************************************************************/
    /*                                           LIBRARY                                        */
    /********************************************************************************************/

    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                      DATA STRUCT & ENUM                                  */
    /********************************************************************************************/
    struct Airline {
        bool isRegistered;
        bool hasPaidFund;
        mapping(address => bool) votedForAirlines;
    }

    struct Flight {
        bool isFlight;
        string code;
        uint256 timestamp;
        uint8 statusCode;
        address airline;
    }

    struct Insurance {
        bool isInsurance;
        bytes32 flightKey;
        uint256 value;
        bool isPayout;
    }

    struct Passenger {
        bool isPassenger;
        mapping(bytes32 => Insurance) insurances;
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

    mapping(bytes32 => Flight) private flights;
    mapping(address => Passenger) private passengers;

    uint256 private airlineBalance = 0;

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

    modifier payableIsPositiveValue(uint256 value){
        require(value > 0, "payable value must be positive");
        _;
    }

    modifier isPassenger(address passenger){
        require(_isPassenger(passenger), "Callis is not passenger");
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

    // ---  Airline

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

    // -- Flight
    function getFlightKey(address airline, string flightCode, uint256 timestamp) external view
    requireAuthorizeContracts requireIsOperational
    returns(bytes32)
    {
        return _getFlightKey(airline, flightCode, timestamp);
    }

    function getFlightStatus(address airline, string flightCode, uint256 timestamp) external view
    requireAuthorizeContracts requireIsOperational returns(uint8)
    {
        bytes32 flightKey = _getFlightKey(airline, flightCode, timestamp);
        require(_existFlight(flightKey), "Is not a valid flight");
        return flights[flightKey].statusCode;
    }

    //  -- Insurance
    function getInsuranceKey(address passenger, bytes32 flightKey) external view
    requireAuthorizeContracts requireIsOperational
    returns(bytes32)
    {
        return _getInsuranceKey(passenger, flightKey);
    }

    // -- Getter

    function getRegisteredAirlineCount() external view returns(uint256 count) {
        count = numberOfRegisteredAirlines;
    }

    // -- Checker

    function checkAirlineIsRegisterd(address airlineAddress) external view requireAuthorizeContracts requireIsOperational returns(bool) {
        return _airlineIsRegistered(airlineAddress);
    }

    function checkAirlineIsPaidFund(address airlineAddress) external view requireAuthorizeContracts requireIsOperational returns(bool) {
        return _airlineIsPaidFund(airlineAddress);
    }

    function checkAirlineIsRegistering(address airlineAddress) external view requireAuthorizeContracts requireIsOperational returns(bool) {
        return _airlineIsRegistering(airlineAddress);
    }

    function checkAirlineBalance() external view requireAuthorizeContracts requireIsOperational returns(uint256) {
        return airlineBalance;
    }

    function checkIsFlight(bytes32 flightKey) external view requireAuthorizeContracts requireIsOperational returns(bool) {
        return _existFlight(flightKey);
    }

    function airlinePaidFunding(address callerAirline)
    external payable
    requireIsOperational requireAuthorizeContracts isAirline(callerAirline) payableIsPositiveValue(msg.value)
    {
        require(!airlines[callerAirline].hasPaidFund, "Calling airline has already paid their funds");
        airlineBalance = airlineBalance.add(msg.value);
        airlines[callerAirline].hasPaidFund = true;
    }

    // ---  Insurance

    // Function: buy insurance
    function buyInsurance(address passenger, bytes32 flightKey, uint256 amountToPaid)
    external payable requireAuthorizeContracts requireIsOperational
    {
        bytes32 insuranceKey = _getInsuranceKey(passenger, flightKey);
        require(passengers[passenger].insurances[insuranceKey].isInsurance == false, "Cannot buy same insurance twice");
        passengers[passenger].isPassenger = true;
        passengers[passenger].insurances[insuranceKey] = Insurance({
            isInsurance: true,
            flightKey: flightKey,
            value: amountToPaid,
            isPayout: false
        });
    }

    // Function: get passenger Insurance record
    function checkInsuranceAmount(bytes32 flightKey, address callerPassenger)
    external view
    requireAuthorizeContracts requireIsOperational isPassenger(callerPassenger) returns(uint256)
    {
        bytes32 insuranceKey = _getInsuranceKey(callerPassenger, flightKey);
        return passengers[callerPassenger].insurances[insuranceKey].value;
    }

    // Function: repayment to passengers who bought insurance

    // Function: passenger withdraw insurance payout

    // -- Flight
    function registerFlight(string flightCode, uint256 timestamp, address callerAirline)
    external requireAuthorizeContracts requireIsOperational isAirline(callerAirline)
    {
        bytes32 flightKey = _getFlightKey(callerAirline, flightCode, timestamp);
        flights[flightKey] = Flight({
            isFlight: true,
            code:flightCode,
            timestamp: timestamp,
            statusCode: 0,
            airline: msg.sender
        });
    }

    function setFlightStatus(
        string flightCode,
        uint256 timestamp,
        uint8 statusCode,
        address callerAirline
    )
    external requireAuthorizeContracts requireIsOperational isAirline(callerAirline)
    {
        bytes32 flightKey = _getFlightKey(callerAirline, flightCode, timestamp);
        require(_existFlight(flightKey), "Flight not exist");
        flights[flightKey].statusCode = statusCode;
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

    function _getFlightKey(address airline, string flightCode, uint256 timestamp) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flightCode, timestamp));
    }

    function _getInsuranceKey(address passenger, bytes32 flightKey) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(passenger, flightKey));
    }

    /********************************************************************************************/
    /*                                        PRIVATE FUNCTIONS                                */
    /********************************************************************************************/

    // --- Airline
    function _airlineIsRegistered(address airlineAddress) private view requireIsOperational returns(bool) {
        return (airlines[airlineAddress].isRegistered);
    }

    function _airlineIsPaidFund(address airlineAddress) private view requireIsOperational returns(bool) {
        return (airlines[airlineAddress].hasPaidFund);
    }

    function _airlineIsRegistering(address airlineAddress) private view requireIsOperational returns(bool) {
        return (registeringAirlines[airlineAddress] > 0);
    }

    function _registerAirline(address newAirlineAddress)
    private requireIsOperational
    {
        // accept the new register
        airlines[newAirlineAddress].isRegistered = true;
        numberOfRegisteredAirlines = numberOfRegisteredAirlines.add(1);
        _voteDone(newAirlineAddress);
        emit AirlineRegistered(newAirlineAddress);
    }

    function _voteDone(address airlineAddressToVote) private requireIsOperational {
        registeringAirlines[airlineAddressToVote] = 0;
    }

    // --- flight
    function _existFlight(bytes32 flightKey) private view requireIsOperational returns(bool){
        return flights[flightKey].isFlight;
    }

    // -- Passenger
    function _isPassenger(address passenger) private view requireIsOperational returns(bool){
        return passengers[passenger].isPassenger;
    }

}