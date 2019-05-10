pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */


contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData private flightSuretyData;

    // app config
    uint8 constant CONSENSUS_THRESHOLD = 4;
    uint8 constant MULTI_PART_CONSENSUS_RATE = 2;
    uint constant JOIN_FEE = 10 ether;
    uint constant MAX_INSURANCE_AMOUNT = 1 ether;

    // Flight status codees
    // enum FlightStatusCode {
    //     Unknow,         // 0
    //     OnTime,         // 1
    //     LateAirline,    // 2
    //     LateWeather,    // 3
    //     LateTechnical,  // 4
    //     LateOther       // 5
    // }

    address private contractOwner;          // Account used to deploy contract

    // struct Flight {
    //     bool isRegistered;
    //     uint8 statusCode;
    //     uint256 updatedTimestamp;
    //     address airline;
    // }
    // mapping(bytes32 => Flight) private flights;

    /********************************************************************************************/
    /*                                    ORACLE DATA VARIABLES                                 */
    /********************************************************************************************/
        // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event Log(string text, uint number);

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

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
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /********************************************************************************************/
    /*                                        EXTERNAL FUNCTIONS                                */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline(address newAirline) external returns(bool success, uint256 votes) {
        uint256 registeredAirlineCount = flightSuretyData.getRegisteredAirlineCount();
        success = false;
        if (registeredAirlineCount >= CONSENSUS_THRESHOLD) {
            votes = flightSuretyData.voteForNewAirline(newAirline, msg.sender);
            if (votes >= (registeredAirlineCount / MULTI_PART_CONSENSUS_RATE)) {
                flightSuretyData.registerAirline(newAirline, msg.sender);
                success = true;
            }
        } else {
            votes = 0;
            flightSuretyData.registerAirline(newAirline, msg.sender);
            success = true;
        }
        return (success, votes);
    }

    function payFunding() external payable {
        require(msg.value >= JOIN_FEE, "Not enough ether to pay");
        uint256 amountToReturn = msg.value - JOIN_FEE;
        flightSuretyData.airlinePaidFunding.value(JOIN_FEE)(msg.sender);
        msg.sender.transfer(amountToReturn);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight(string flightCode, uint256 timestamp) external {
        require(flightSuretyData.checkIsFlight(getFlightKey(msg.sender, flightCode, timestamp)) == false, "Flight already registered");
        flightSuretyData.registerFlight(flightCode, timestamp, msg.sender);
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string flight, uint256 timestamp) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(
            index,
            airline,
            flight,
            timestamp));
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(
            index,
            airline,
            flight,
            timestamp
        );
    }

    // -- Insurance
    function buyInsurance(
        address passenger,
        address airline,
        string flightCode,
        uint256 timestamp,
        uint256 amountToPaid
    ) external payable
    {
        require(flightSuretyData.checkAirlineIsRegisterd(passenger) == false, "Airline cannot buy insurance");
        require(flightSuretyData.checkAirlineIsRegisterd(airline), "airline address incorrect");
        bytes32 flightKey = getFlightKey(airline, flightCode,  timestamp);
        require(flightSuretyData.checkIsFlight(flightKey), "Flight not exisit");
        require(amountToPaid > 0, "Insurance amount must > 0");
        require(amountToPaid <= MAX_INSURANCE_AMOUNT, "Insurance amount is over the limit");
        require(msg.value >= amountToPaid, "Not enough ether to pay");
        uint256 amountToReturn = msg.value - amountToPaid;
        flightSuretyData.buyInsurance.value(amountToPaid)(passenger, flightKey, amountToPaid);
        msg.sender.transfer(amountToReturn);
    }

    function checkInsuranceAmount(address airline,  string flightCode, uint256 timestamp) external view returns(uint256){
        bytes32 flightKey = getFlightKey(airline, flightCode,  timestamp);
        return flightSuretyData.checkInsuranceAmount(flightKey, msg.sender);
    }

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
            isRegistered: true,
            indexes: indexes
        });
    }

    function getMyIndexes() external view returns(uint8[3]) {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external
    {
        require(
            (oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(
                index,
                airline,
                flight,
                timestamp
            )
        );

        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(
            airline,
            flight,
            timestamp,
            statusCode
        );
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(
                airline,
                flight,
                timestamp,
                statusCode
            );

            // Handle flight status as appropriate
            processFlightStatus(
                airline,
                flight,
                timestamp,
                statusCode
            );
        }
    }

    /********************************************************************************************/
    /*                                       PUBLIC FUNCTIONS                                   */
    /********************************************************************************************/

    function isOperational() public pure returns(bool) {
        return true;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                        INTERNAL FUNCTIONS                                */
    /********************************************************************************************/

    /**
    * @dev Called after oracle has updated flight status
    *
    */

    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode) internal pure
    {

    }

    function getFlightKey(address airline, string flightCode, uint256 timestamp) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flightCode, timestamp));
    }

    function getInsuranceKey(address passenger, bytes32 flightKey) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(passenger, flightKey));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns(uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion
}

contract FlightSuretyData {
    // -- Airline
    function registerAirline(address newAirline, address callerAirline) external;
    function checkAirlineIsRegisterd(address airlineAddress) external view returns(bool);
    function voteForNewAirline(address newAirlineAddress, address callerAirline) external returns(uint256 votes);
    function getRegisteredAirlineCount() external view returns(uint256 count);
    function airlinePaidFunding(address callerAirline) external payable;
    // -- Flight
    function registerFlight(string flightCode, uint256 timestamp, address callerAirline) external;
    function checkIsFlight(bytes32 flightKey) external view returns(bool);
    // -- Insurance
    function buyInsurance(address passenger, bytes32 flightKey, uint256 amountToPaid) external payable;
    function checkInsuranceAmount(bytes32 flightKey, address callerPassenger)external view returns(uint256);
}