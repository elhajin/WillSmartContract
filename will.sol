//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Will
 * @author Ehaj
 * @notice This smart contract is an implementation of a will that anyone can set to ensure that
 * @notice the funds in this smart contract goes to the right hands that he set
 */

contract Will {
    //custom errors:
    error WillError__InheritorExist();
    error WillError__NotInheritor(address caller);
    error WillError__NotOwner(address caller);
    error WillError__NotValidPercentage(uint8 maxPercentage);
    error WillError__TxFailed();
    error WillError__YouAllowToWithdraw();
    error WillError__NotAllowedYet(uint256 timeLeft);
    error WillError__RequestAlreadyExist(uint256 requestTimestamp);
    error WillError__DidWithdraw(address caller);

    event AddInheritor(address indexed inheritor, uint256 indexed percentage);
    event RemoveInheritor(
        address indexed inheritor,
        uint256 indexed availabelpercentage
    );
    event OwnerWithdraw(address indexed owner, uint256 amount);
    event RequestToWithdraw(address indexed caller, uint256 indexed time);
    event InheritorWithdraw(address indexed inheritor, uint256 indexed value);

    bool private allowWithdraw; // the main variables that if it's true means any inheritor can withdraw

    struct Inheritor {
        string description; // [opt] a description of an inheritor
        uint8 percentage; // the percentage the owner set to the inheritor
        uint256 id; // the id of the inheritor
        bool didWithdraw; // if the inheritor did withdraw or not yet
    }

    struct RequestWithdraw {
        bool requestExsit; // if there is a request made by an inheritor;
        uint256 timestamp; // the time when the reques set
        address caller; // the inheritor that made the request
    }

    RequestWithdraw private requestWithdraw; //if there is a request to withdraw any inheritor can set it by passing some conditions;

    address payable mainInheritor; //after last inheritor withdrawed the contract get destroyed and the funds send to this address
    address owner; // the owner of the contract gonna be the deployer ;
    uint16 countInheritors; //this will be the number of inheritors the owner set;
    uint256 public duration; //time to pass from sending request to allow the inheritor to withdraw thier share
    uint256 public lastUpdate; // changes when the owner cancel requests;(it will change when ever the owner interact with the contract)
    uint256 public fromLastUpdate; // have to pass lastUdate + fromLastUpdate to send a new request;

    uint256 private tokenForEachPercentage;
    uint8 private availablePercentage = 100; //the percentage available for inherit;

    mapping(address => bool) public isInheritor; //check if this address is inheritor of the owner
    mapping(address => Inheritor) private inheritor; //mapping to get the inheritors ;

    modifier onlyInheritors() {
        if (!isInheritor[msg.sender]) {
            revert WillError__NotInheritor(msg.sender);
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert WillError__NotOwner(msg.sender);
        _;
        lastUpdate = block.timestamp;
    }

    modifier allowInheritorWithdraw() {
        if (block.timestamp < duration + requestWithdraw.timestamp) {
            revert WillError__NotAllowedYet(_timeLeft());
        }
        if (!allowWithdraw) {
            allowWithdraw = true;
        }
        if (tokenForEachPercentage == 0) {
            tokenForEachPercentage = _amountForEachPercentage();
        }

        if (inheritor[msg.sender].didWithdraw) {
            revert WillError__DidWithdraw(msg.sender);
        }
        _;
    }

    modifier allowRequestWithdraw() {
        if (allowWithdraw) revert WillError__YouAllowToWithdraw();
        if (requestWithdraw.requestExsit) {
            revert WillError__RequestAlreadyExist(requestWithdraw.timestamp);
        }
        if (block.timestamp < lastUpdate + fromLastUpdate) {
            revert WillError__NotAllowedYet(_timeLeft());
        }
        _;
    }

    constructor(uint256 _duration, uint256 _fromLastUpdate) payable {
        require(msg.sender != address(0));
        owner = msg.sender;
        duration = (_duration) * 1 days;
        fromLastUpdate = _fromLastUpdate * 1 days;
    }

    receive() external payable {}

    fallback() external payable {}

    // write functions :

    function addInheritor(
        string memory description,
        address _inheritor,
        uint8 _percentage
    ) public onlyOwner {
        require(_inheritor != address(0));
        if (isInheritor[_inheritor]) revert WillError__InheritorExist();
        if (_percentage > availablePercentage) {
            revert WillError__NotValidPercentage(availablePercentage);
        }
        availablePercentage -= _percentage;
        inheritor[_inheritor] = Inheritor(
            description,
            _percentage,
            countInheritors,
            false
        );
        countInheritors += 1;

        isInheritor[_inheritor] = true;
        emit AddInheritor(_inheritor, _percentage);
    }

    function removeInheritor(address _inheritor) public onlyOwner {
        if (!isInheritor[_inheritor]) {
            revert WillError__NotInheritor(_inheritor);
        }
        isInheritor[_inheritor] = false; // set the mapping to false
        countInheritors -= 1; //decrease the count of inheritors by one ;
        uint8 perce = inheritor[_inheritor].percentage; //fetch percentage to add after to the availabel percantage
        Inheritor memory setToDefault; //delete the inheritor struct
        availablePercentage += perce; //add the percantage of the available percentage

        inheritor[_inheritor] = setToDefault;

        emit RemoveInheritor(_inheritor, availablePercentage);
    }

    function changeInheritorPersantage(
        address _inheritor,
        uint8 newPercentage
    ) public onlyOwner {
        if (!isInheritor[_inheritor]) {
            revert WillError__NotInheritor(_inheritor);
        }

        if (
            newPercentage >
            availablePercentage + inheritor[_inheritor].percentage
        ) {
            revert WillError__NotValidPercentage(
                availablePercentage + inheritor[_inheritor].percentage
            );
        }
        availablePercentage =
            availablePercentage +
            inheritor[_inheritor].percentage -
            newPercentage;

        inheritor[_inheritor].percentage = newPercentage;
    }

    function ownerWithdraw(uint256 amount) public onlyOwner {
        require(!allowWithdraw, "-allowWithdraw- required to be false");
        (bool seccess, ) = payable(owner).call{value: amount}("");
        if (!seccess) revert WillError__TxFailed();

        emit OwnerWithdraw(msg.sender, amount);
    }

    function changeDuration(uint256 newDuration) public onlyOwner {
        duration = newDuration * 1 days;
    }

    function changeFromLastUpdate(uint256 _fromLastUpdate) public onlyOwner {
        fromLastUpdate = _fromLastUpdate * 1 days;
    }

    function cancleRequests() public onlyOwner {
        require(!allowWithdraw, "Too Late To Cancle");
        require(requestWithdraw.requestExsit, "no request to cancle");
        RequestWithdraw memory reset;
        requestWithdraw = reset;
    }

    function setMainInheritor(address payable _mainInheritor) public onlyOwner {
        mainInheritor = _mainInheritor;
    }

    function blockWithdraw() public onlyOwner {
        require(allowWithdraw, "No need to block it");
        allowWithdraw = false;
        tokenForEachPercentage = 0;
    }

    // inheritors functions :
    function requestToWithdraw() public onlyInheritors allowRequestWithdraw {
        requestWithdraw = RequestWithdraw(true, block.timestamp, msg.sender);

        emit RequestToWithdraw(msg.sender, block.timestamp);
    }

    function inheritorWithdraw() public onlyInheritors allowInheritorWithdraw {
        require(allowWithdraw);
        countInheritors -= 1;
        uint256 val = _getYouCount(inheritor[msg.sender].percentage);
        inheritor[msg.sender].didWithdraw = true;
        if (countInheritors == 0) {
            (bool seccess, ) = msg.sender.call{value: val}("");
            require(seccess);
            emit InheritorWithdraw(msg.sender, val);
            selfdestruct(mainInheritor);
        } else {
            (bool seccess, ) = msg.sender.call{value: val}("");
            require(seccess);
            emit InheritorWithdraw(
                msg.sender,
                val
            ); /* for test check if the state of the didWithdraw not changes if tx failed*/
        }
    }

    //read functions:
    //tested: 5
    function getOwner() public view returns (address) {
        return owner;
    }

    //tested: 8
    function getYourCurrentAmount()
        public
        view
        onlyInheritors
        returns (uint256)
    {
        return _amountForEachPercentage() * inheritor[msg.sender].percentage;
    }

    //tested: 8
    function getInheritorPercentage(
        address _inheritor
    ) public view returns (uint8) {
        return inheritor[_inheritor].percentage;
    }

    //tested: 8
    function getInheritorCount() public view returns (uint16) {
        return countInheritors;
    }

    //tested: 5
    function getAvailablePercentage() public view returns (uint8) {
        return availablePercentage;
    }

    //no need to test;
    function getRequestWithdraw() public view returns (RequestWithdraw memory) {
        return requestWithdraw;
    }

    function getInheritor(address add) public view returns (Inheritor memory) {
        return inheritor[add];
    }

    function getWillState() public view returns (string memory) {
        if (allowWithdraw) {
            return "INHERITORS WITHDRAW";
        } else if (!allowWithdraw && requestWithdraw.requestExsit) {
            return "REQUEST WITHDRAW";
        } else {
            return "OWNER";
        }
    }

    //helper functions :

    function _timeLeft() private view returns (uint256) {
        uint256 timeleft;
        if (requestWithdraw.requestExsit) {
            timeleft = (duration + requestWithdraw.timestamp) - block.timestamp;
        } else {
            if (block.timestamp > lastUpdate + fromLastUpdate) {
                timeleft = duration;
            } else {
                timeleft = duration + fromLastUpdate;
            }
        }
        return timeleft;
    }

    function _amountForEachPercentage() private view returns (uint256 forEach) {
        forEach = address(this).balance / 100;
    }

    function _getYouCount(
        uint256 percentage
    ) private view returns (uint256 count) {
        count = tokenForEachPercentage * percentage;
    }
}
