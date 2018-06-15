pragma solidity ^0.4.15;

// Contract that:
//      Lets anyone bet with x ethers
//      When it reaches y bets, it will chooses a gambler randomly and
//      sends z% of the ethers received. other v% goes to GiveDirectly


contract Lottery {
    // owner of the contract
    address owner;

    address [] public players;

    bool public isLotteryLive;
    string public contract_name;

    uint public ante; //how big is the bet per person (in ether)
    uint8 public required_number_players; //how many sign ups trigger the lottery
    uint8 public next_round_players; //how many sign ups trigger the lottery
    uint public winner_percentage; // how much does the winner get (in percentage)


    uint public round; // how many round
    address [] public winners; // winner list

    //constructor
    function Lottery(){
        owner = msg.sender;
        round = 1;
        ante = 1 ether;
        required_number_players = 6;
        winner_percentage = 80;
        isLotteryLive = true;
        contract_name = "one ether for treasure";
    }

    function start() public restricted {
        isLotteryLive = true;
    }

    function stop() public restricted {
        isLotteryLive = false;
    }

    function update(uint newAnte, uint8 newNumberOfPlayers, uint newWinnerPercentage) restricted{
         if (newAnte > uint80(0)) {
            ante = newAnte;
        }
        if (newNumberOfPlayers > uint80(0)) {
            required_number_players = newNumberOfPlayers;
        }
        if ((newWinnerPercentage > uint80(0)) && (newWinnerPercentage < uint80(100))) {
            winner_percentage = newWinnerPercentage;
        }
    }

    /**
    * return the ether back
    */
    function refund() private restricted {
        isLotteryLive = false;
        uint i = 0;
        for (i; i < players.length; i++) {
            if (this.balance < ante) {
                break;
            }
            players[i].transfer(ante);
        }
        players[i].transfer(ante);
    }

    function getBalance() public view returns (uint256) {
        return this.balance;
    }

    function getActive() public view returns (bool){
        return isLotteryLive;
    }

    function destory() restricted {
        refund();
        selfdestruct(owner);
    }

    function getPlayers() public view returns(address[]) {
        return players;
    }

    function getWinners() public view returns(address[]) {
        return winners;
    }

    function getRound() public view returns(uint) {
        return round;
    }


    // function when someone gambles a.k.a sends ether to the contract
    function () payable {
        // No arguments are necessary, all information is already part of the transaction.
        // The keyword payable is required for the function to be able to receive Ether.
        require(isLotteryLive);
        // If the bet is not equal to the ante, send the money back.
        if(msg.value != ante) throw; // give it back, revert state changes, abnormal stop

        players.push(msg.sender);
        // event
        emit Log(msg.sender, players.length);

        if (round * required_number_players == players.length) {
            isLotteryLive = false;
            // pick a random number between 1 and required_number_players
            var index = random(required_number_players);
            // ante*required_number_players*winner_percentage/100
            uint256 winner_bonus = mul(mul(ante, required_number_players), winner_percentage) / 100;
            uint256 owner_bonus = sub(mul(ante, required_number_players), winner_bonus);
            var winner = players[index];
            winner.transfer(winner_bonus);
            owner.transfer(owner_bonus);
            winners.push(winner);
            // event
            emit AnnounceWinner(round, winner, winner_bonus);
            round += 1;
            isLotteryLive = true;

        }
    }


    function random(uint256 upper) public returns (uint256 randomNumber) {
        var seed = uint256(
            keccak256(
            now,
            block.blockhash(block.number - 1),
            block.coinbase,
            block.difficulty));
        return seed % upper;
    }

    modifier restricted() {
        require(msg.sender == owner);
        _;
    }

    // Events
    event Log(address indexed _addr, uint indexed _index);
    event AnnounceWinner(uint indexed _round, address indexed _winner, uint256 indexed _value);

    // Math
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        c = a * b;
        assert(c / a == b);
        return c;
    }
}
