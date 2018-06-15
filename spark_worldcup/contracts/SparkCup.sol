pragma solidity ^0.4.23;
import "./ERC721.sol";
import "./SafeMath.sol";

/**
 * @title Spark World Cup Contract
 * @author zhicai
 */

contract SparkCup {

  /**
   * Private variables
   */
   uint256 private initialPrice = 0.01 ether;
   uint256 private maxPrice = 200 ether;

   // Profit of selling a team, 5% to developer, 25% to Prizes Pool, 70% to owner
   uint256 private developerShare = 5;
   uint256 private prizesPoolShare = 25;
   uint256 private ownerShare = 70;
   bool private alreadyCreatedTeam;
   bool locked; // FOR MODIFIER
   mapping (address => uint256) private ownerTeamCount;
   mapping (uint256 => address) private teamOwners;
   Prizes private prizes;
   Team[] private teams;

  /**
   * Storage
   */
   mapping (address => uint256) public matchPrizeBank;
   mapping (uint256 => address) public teamToApproved;
   mapping(uint256 => Match) public matches;
   address public contractModifier;
   address public developer;

  /**
   * Constructor
   * Define contract MODIFIER, developer address.
   * Initialize prize values.
   */
   constructor() public {
      contractModifier = msg.sender;
      developer = msg.sender;
      prizes.last16PoolTotal = 0;
      prizes.last16Locked = false;
      prizes.quarterPoolTotal = 0;
      prizes.quarterLocked = false;
      prizes.semiPoolTotal = 0;
      prizes.semiLocked = false;
      prizes.finalPoolTotal = 0;
   }

  /**
   * Data structure
   */

   // Betting WorldCup
   struct Better {
       address add;
       uint256 investedAmount;
       uint256 bet; //1->player1 win, 2->player2 win, 3->tie
   }

   struct Match {
       uint256 matchId;
       uint256 startTime;
       uint256 teamId1;
       uint256 teamId2;
       uint256 result; //0->nothing, 1->player1 win, 2->player2 win, 3->tie
       uint256 investPool;
       uint256 bettersCount;
       mapping(uint256 => Better) betters;
   }

   struct Team {
      string name;
      string code;
      uint256 price;
      uint256 lastSoldPrice;
      uint256 txCount;
      uint256 rewardCount;
      address owner;
      mapping (uint256 => TeamTxRecord) teamTxRecords;
      mapping (uint256 => TeamReward) teamRewards;
   }

   struct TeamTxRecord {
      uint256 price;
      uint256 time;
      address from;
      address to;
   }

   struct TeamReward {
      uint256 amount;
      uint256 rewardTime;
      address to;
      string stage;
   }

   struct Prizes {
       uint256 last16PoolTotal;
       bool last16Locked;
       uint256 quarterPoolTotal;
       bool quarterLocked;
       uint256 semiPoolTotal;
       bool semiLocked;
       uint256 finalPoolTotal;
   }

   /**
    * Modifier
    */
    modifier onlyContractModifier() {
        require(msg.sender == contractModifier);
        _;
    }

    modifier noReentrancy() {
        if(locked) revert();

        locked = true;

        _;

        locked = false;
    }

    // Events
    event Transfer(address indexed from, address indexed to, uint256 tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 tokenId);
    event TeamSold(uint256 indexed team, address indexed from, uint256 oldPrice, address indexed to, uint256 newPrice, uint256 tradingTime, uint256 balance);
    event test_value(uint256 indexed value1);

   /**
    * Public functions
    */
    // Fallback
    function () public payable {
        revert();
    }

    function addMatch(uint256 matchId, uint256 startTime, uint256 teamId1, uint256 teamId2) public onlyContractModifier returns (bool result) {
       require(startTime > now);
       require(matchId >= 0);
       require(teamId1 >= 0 && teamId1 <= 32);
       require(teamId2 >= 0 && teamId2 <= 32);

       Match memory _match = Match(matchId, startTime, teamId1, teamId2, 0, 0, 0);
       matches[matchId] = _match;

       return true;
   }

   function betMatch(uint256 matchId, uint256 bet) public payable returns(bool result) {
       //0->nothing, 1->player1 win, 2->player2 win, 3->tie
       require (matchId >= 0 && bet > 0 && bet < 4);
       require (msg.value > 0);
       require (msg.sender != developer);

       Match storage _match = matches[matchId];
       require(_match.result == 0 && _match.startTime > now);

       Better storage better = _match.betters[_match.bettersCount];
       better.add = msg.sender;
       better.investedAmount = msg.value;
       better.bet = bet;

       _match.investPool = SafeMath.add(_match.investPool, msg.value);
       _match.bettersCount++;

       return true;
  }

  function getMatch(uint256 matchId) public constant returns (uint256[]) {
      require(matchId >= 0);
      Match storage _match = matches[matchId];
      uint256[] memory data = new uint256[](7);
      data[0] = _match.matchId;
      data[1] = _match.startTime;
      data[2] = _match.teamId1;
      data[3] = _match.teamId2;
      data[4] = _match.result;
      data[5] = _match.investPool;
      data[6] = _match.bettersCount;
      return data;
  }

   // For testing
   function getNow() public constant returns(uint256) {
      return now;
   }

   // Set match result and Distribute Prizes
   function setMatchAndPrize(uint256 matchId, uint256 result) public onlyContractModifier returns(bool) {
       require(matchId >= 0);
       require(result > 0 && result < 4);
       Match storage _match = matches[matchId];

       require(_match.result == 0);
       _match.result = result;

       // Winners profit = losers invested
       // Winner profit = (winner invest / all winners invested) * losers invested
       uint256 losersInvested = 0;
       uint256 i = 0;
       emit test_value(_match.bettersCount);

       for(i = 0; i < _match.bettersCount; i++) {
            Better memory better = _match.betters[i];
            if(better.bet != result && better.investedAmount > 0){
                losersInvested = SafeMath.add(losersInvested, better.investedAmount);
            }
        }

        if(losersInvested > 0 && _match.investPool > losersInvested) {
            // Team owner profit 15%, prize pool 5%
            uint256 onePercent = SafeMath.div(losersInvested, 100);
            //uint256 teamOwnerProfit = SafeMath.mul(onePercent, 15);
            //uint256 prizePoolProfit = SafeMath.mul(onePercent, 5);
            uint256 winnersProfit = SafeMath.mul(onePercent, 80);
            uint256 winnersInvested = SafeMath.sub(_match.investPool, losersInvested);

            // TODO
            //address teamOwner = teams[_match.teamId1].owner;
            //teamOwner.transfer(teamOwnerProfit);

            i = 0;
            uint256 share = 0;
            uint256 gain = 0;

            for(i = 0; i < _match.bettersCount; i++) {
                Better memory _better = _match.betters[i];

                if(_better.bet == result && _better.investedAmount > 0){

                    share = SafeMath.div(_better.investedAmount, winnersInvested);
                    gain = SafeMath.add(_better.investedAmount, SafeMath.mul(winnersProfit, share));
                    matchPrizeBank[_better.add] = SafeMath.add(matchPrizeBank[_better.add], gain);
                    // _better.add.transfer(gain);
                }
            }
        }

        return true;
   }

    function matchWithdraw() external noReentrancy returns(bool) {
      uint256 refund = matchPrizeBank[msg.sender];
      require (refund > 0);
      matchPrizeBank[msg.sender] = 0;

      //TODO
      msg.sender.transfer(refund);
      //if(!msg.sender.call.gas(3000000).value(refund)) throw;

      return true;
    }

    function getBalance() public view returns (uint256 _balance) {
      _balance = matchPrizeBank[msg.sender];
    }

    function getContractBalance() public view returns (uint256 _contractBalance) {
        _contractBalance = address(this).balance;
    }

    /**
     * Buying a team, double the price until 10 ether
     */
    function buyTeam(uint256 tokenId) public payable {
        address currentOwner = teams[tokenId].owner;
        uint256 currentPrice = teams[tokenId].price;

        require(currentOwner != msg.sender);
        //require(msg.sender != developer);
        require(msg.value >= currentPrice);

        Team storage team = teams[tokenId];

        uint256 newPrice = currentPrice;
        if(currentPrice < maxPrice) {
            newPrice = SafeMath.div(SafeMath.mul(currentPrice, 200), 100);
        }

        // emit test_value(newPrice); // log the current value
        // Payments: 5% to developer, 25% to Prizes Pool, 70% to owner
        uint256 profit = SafeMath.sub(msg.value, team.lastSoldPrice);
        emit test_value(profit);

        uint256 onePercent = SafeMath.div(profit, 100);
        emit test_value(onePercent);

        uint256 developerProfit = SafeMath.mul(onePercent, developerShare);
        emit test_value(developerProfit);

        uint256 prizesPoolProfit = SafeMath.mul(onePercent, prizesPoolShare);
        emit test_value(prizesPoolProfit);

        uint256 ownerProfit = SafeMath.add(SafeMath.mul(onePercent, ownerShare), team.lastSoldPrice);
        emit test_value(ownerProfit);

        // Paying developer
        matchPrizeBank[developer] = SafeMath.add(matchPrizeBank[developer], developerProfit);
        emit test_value(matchPrizeBank[developer]);
        // developer.transfer(developerProfit);

        // Paying owner
        matchPrizeBank[currentOwner] = SafeMath.add(matchPrizeBank[currentOwner], ownerProfit);
        emit test_value(matchPrizeBank[currentOwner]);
        // currentOwner.transfer(ownerProfit);

        // Calculating each Prize Pool
        uint256 slice = 0;
        if(!prizes.last16Locked) {
            slice = SafeMath.div(prizesPoolProfit, 4);
            prizes.last16PoolTotal += slice;
            prizes.quarterPoolTotal += slice;
            prizes.semiPoolTotal += slice;
            prizes.finalPoolTotal += slice;
        } else if(!prizes.quarterLocked){
            slice = SafeMath.div(prizesPoolProfit, 3);
            prizes.quarterPoolTotal += slice;
            prizes.semiPoolTotal += slice;
            prizes.finalPoolTotal += slice;
        } else if(!prizes.semiLocked){
            slice = SafeMath.div(prizesPoolProfit, 2);
            prizes.semiPoolTotal += slice;
            prizes.finalPoolTotal += slice;
        } else {
            prizes.finalPoolTotal += prizesPoolProfit;
        }

        // Update tx record
        team.owner = msg.sender;
        team.price = newPrice;
        team.lastSoldPrice = currentPrice;
        team.teamTxRecords[team.txCount++] = TeamTxRecord ({
            price: currentPrice,
            time: uint256(now),
            from: currentOwner,
            to: msg.sender
        });

        //_transfer(teams[tokenId].owner, msg.sender, tokenId);
        ownerTeamCount[msg.sender]++;

        emit TeamSold(tokenId, currentOwner, currentPrice, msg.sender, newPrice, uint256(now), address(this).balance);

    }

    function getTeam(uint256 tokenId) public view returns (
        uint256 _tokenId,
        string _name,
        string _code,
        uint256 _price,
        uint256 _lastSoldPrice,
        uint256 _txCount,
        uint256 _rewardCount,
        address _owner)
    {
        require(tokenId < teams.length);
        Team storage team = teams[tokenId];
        _tokenId = tokenId;
        _name = team.name;
        _code = team.code;
        _price = team.price;
        _lastSoldPrice = team.lastSoldPrice;
        _txCount = team.txCount;
        _rewardCount = team.rewardCount;
        _owner = team.owner;
     }

    function getTeamTxRecords(uint256 tokenId, uint256 recordId) public view returns (
        uint256 price,
        uint256 time,
        address from,
        address to)
    {
        require(tokenId < teams.length);
        require(recordId < teams[tokenId].txCount);

        TeamTxRecord storage record = teams[tokenId].teamTxRecords[recordId];
        price = record.price;
        time = record.time;
        from = record.from;
        to = record.to;
    }

    function getPrizePool() public view returns (
        uint256 last16PoolTotal,
        bool last16Locked,
        uint256 quarterPoolTotal,
        bool quarterLocked,
        uint256 semiPoolTotal,
        bool semiLocked,
        uint256 finalPoolTotal)
    {
        last16PoolTotal = prizes.last16PoolTotal;
        last16Locked = prizes.last16Locked;
        quarterPoolTotal = prizes.quarterPoolTotal;
        quarterLocked = prizes.quarterLocked;
        semiLocked = prizes.semiLocked;
        semiPoolTotal = prizes.semiPoolTotal;
        finalPoolTotal = prizes.finalPoolTotal;
    }

    // Lock 16, fund wont goes to the 16 pool anymore
    function lock16Fund() public onlyContractModifier {
        prizes.last16Locked = true;
    }

    // Distribute 16 prizes pool, 8 winners
    function distribute16PrizeWinners (uint256 teamToken) public onlyContractModifier {
        uint256 slice = SafeMath.div(prizes.last16PoolTotal, 8);

        Team storage team = teams[teamToken];
        require(team.rewardCount == 0);

        // transfer to account
        // team.owner.transfer(slice);
        matchPrizeBank[team.owner] = SafeMath.add(matchPrizeBank[team.owner], slice);

        team.teamRewards[team.rewardCount++] = TeamReward({
            amount: slice,
            rewardTime: uint256(now),
            to: team.owner,
            stage: "Sixteen Round Winner"
        });
    }

    // Distribute Quarter prizes pool, 4 winners
    function distributeQuarterPrizeWinners (uint256 teamToken) public onlyContractModifier {
        uint256 slice = SafeMath.div(prizes.quarterPoolTotal, 4);

        Team storage team = teams[teamToken];
        require(team.rewardCount == 1);

        // transfer to account
        // team.owner.transfer(slice);
        matchPrizeBank[team.owner] = SafeMath.add(matchPrizeBank[team.owner], slice);

        team.teamRewards[team.rewardCount++] = TeamReward({
            amount: slice,
            rewardTime: uint256(now),
            to: team.owner,
            stage: "Quarter Winner"
        });
    }

    // Distribute Semi-Quarter prizes pool, 2 winners
    function distributeSemiPrizeWinners (uint256 teamToken) public onlyContractModifier {
        uint256 slice = SafeMath.div(prizes.semiPoolTotal, 2);

        Team storage team = teams[teamToken];
        require(team.rewardCount == 2);

        // transfer to account
        // team.owner.transfer(slice);
        matchPrizeBank[team.owner] = SafeMath.add(matchPrizeBank[team.owner], slice);

        team.teamRewards[team.rewardCount++] = TeamReward({
            amount: slice,
            rewardTime: uint256(now),
            to: team.owner,
            stage: "Semi-Quarter Winner"
        });
    }
    // Distribute Final prizes pool, 1 winners
    function distributeFinalPrizeWinners (uint256 teamToken) public onlyContractModifier {
        Team storage team = teams[teamToken];
        require(team.rewardCount == 3);

        // team.owner.transfer(prizes.finalPoolTotal);
        matchPrizeBank[team.owner] = SafeMath.add(matchPrizeBank[team.owner], prizes.finalPoolTotal);

        team.teamRewards[team.rewardCount++] = TeamReward({
            amount: prizes.finalPoolTotal,
            rewardTime: uint256(now),
            to: team.owner,
            stage: "Final Winner"
        });
    }

    // Lock Quarter, fund wont goes to the Quarter pool anymore
    function lockQuarterFund() public onlyContractModifier {
        prizes.quarterLocked = true;
    }

    // Lock Semi, fund wont goes to the Semi pool anymore
    function lockSemiFund() public onlyContractModifier {
        prizes.semiLocked = true;
    }

    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
   function balanceOf(address _owner) public view returns (uint256 balance) {
      return ownerTeamCount[_owner];
   }

   function implementsERC721() public pure returns (bool) {
      return true;
   }

   function tokenName() public pure returns (string) {
       return "SparkCupToken";
   }

   function symbol() public pure returns (string) {
       return "SCT";
   }

    /// @notice Find the owner of an NFT
    /// @param _tokenId The identifier for an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) public view returns (address owner) {
      owner = teamOwners[_tokenId];
      require(owner != address(0));
      return owner;
    }


    function takeOwnership(uint256 _tokenId) public {
      address to = msg.sender;
      address from = teamOwners[_tokenId];
      require(from != to);
      require(_addressNotNull(to));
      require(_approved(to, _tokenId));
      _transfer(from, to, _tokenId);
    }

    function totalSupply() public view returns (uint256 total) {
      return teams.length;
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public {
      // do something here...
      require(msg.sender == teams[_tokenId].owner);
      require(_from != _to);
      require(_addressNotNull(_to));
      require(_approved(_to, _tokenId));
      _transfer(_from, _to, _tokenId);
    }

    function transfer(address _to, uint256 _tokenId) public {
      // do something here...
      require(msg.sender == teams[_tokenId].owner);
      require(_addressNotNull(_to));
      _transfer(msg.sender, _to, _tokenId);
    }

   function approve(address _to, uint256 _tokenId) public {
       require(_owns(msg.sender, _tokenId));
       teamToApproved[_tokenId] = _to;
       emit Approval(msg.sender, _to, _tokenId);
    }

    function destroy() public onlyContractModifier {
 	    selfdestruct(contractModifier);
    }


    function createTeams() public onlyContractModifier {
        require(!alreadyCreatedTeam);

        _createTeam("Russia", "RUS", initialPrice, 0, 0, developer);
        _createTeam("Saudi Arabia", "KSA", initialPrice, 0, 0, developer);
        _createTeam("Egypt", "EGY", initialPrice, 0, 0, developer);
        _createTeam("Uruguay", "URU", initialPrice, 0, 0, developer);
        _createTeam("Portugal", "POR", initialPrice, 0, 0, developer);
        _createTeam("Spain", "SPA", initialPrice, 0, 0, developer);
        _createTeam("Morocco", "MOR", initialPrice, 0, 0, developer);
        _createTeam("Iran", "IRN", initialPrice, 0, 0, developer);
        _createTeam("France", "FRA", initialPrice, 0, 0, developer);
        _createTeam("Australia", "AUS", initialPrice, 0, 0, developer);
        _createTeam("Peru", "PER", initialPrice, 0, 0, developer);
        _createTeam("Denmark", "DEN", initialPrice, 0, 0, developer);
        _createTeam("Argentina", "ARG", initialPrice, 0, 0, developer);
        _createTeam("Iceland", "ICE", initialPrice, 0, 0, developer);
        _createTeam("Croatia", "CRO", initialPrice, 0, 0, developer);
        _createTeam("Nigeria", "NGA", initialPrice, 0, 0, developer);
        _createTeam("Brazil", "BRZ", initialPrice, 0, 0, developer);
        _createTeam("Switzerland", "SWI", initialPrice, 0, 0, developer);
        _createTeam("Costa Rica", "CRC", initialPrice, 0, 0, developer);
        _createTeam("Serbia", "SER", initialPrice, 0, 0, developer);
        _createTeam("Germany", "GER", initialPrice, 0, 0, developer);
        _createTeam("Mexico", "MEX", initialPrice, 0, 0, developer);
        _createTeam("Sweden", "SWE", initialPrice, 0, 0, developer);
        _createTeam("South Korea", "KOR", initialPrice, 0, 0, developer);
        _createTeam("Belgium", "BEL", initialPrice, 0, 0, developer);
        _createTeam("Panama", "PAN", initialPrice, 0, 0, developer);
        _createTeam("Tunisia", "TUN", initialPrice, 0, 0, developer);
        _createTeam("England", "ENG", initialPrice, 0, 0, developer);
        _createTeam("Poland", "POL", initialPrice, 0, 0, developer);
        _createTeam("Senegal", "SEN", initialPrice, 0, 0, developer);
        _createTeam("Colombia", "COL", initialPrice, 0, 0, developer);
        _createTeam("Japan", "JPN", initialPrice, 0, 0, developer);

        alreadyCreatedTeam = true;
    }

  /**
    * Private functions
    */

    function _createTeam(string name, string code, uint256 price, uint256 lastSoldPrice, uint256 txCount, address owner) private {
        Team memory team = Team(name, code, price, lastSoldPrice, txCount, 0, owner);

        // token ID
        // push return number of teams, -1 for index
        uint256 teamId = teams.push(team) - 1;

        // Transfer owner will be developer's address
        _transfer(address(0), owner, teamId);
    }

    function _owns(address _claimant, uint256 _tokenId) private view returns (bool) {
        return _claimant == teamOwners[_tokenId];
    }

    function _transfer(address from, address to, uint256 tokenId) private {
        require (tokenId <= teams.length);

        // Team storage ref.
        // teams[tokenId] = to;
        Team storage team = teams[tokenId];
        team.owner = to;
        teamOwners[tokenId] = to;

        ownerTeamCount[to]++;
        if (_addressNotNull(from)) {
            ownerTeamCount[from]--;
            delete teamToApproved[tokenId];
        }
        // Event
        emit Transfer(from, to, tokenId);
    }

    function _approved(address _to, uint256 _tokenId) private view returns (bool) {
        return teamToApproved[_tokenId] == _to;
    }

    function _addressNotNull(address _address) private pure returns (bool) {
        return _address != address(0);
    }

    // FOR TESTING ONLY
    function _createMatch() public onlyContractModifier returns(bool) {
        addMatch(0, 1529074800, 1, 0);
        addMatch(1, 1529064000, 3, 2);
        addMatch(2, 1529074800, 6, 7);
        addMatch(3, 1529085600, 5, 4);
        addMatch(4, 1529143200, 9, 8);
        addMatch(5, 1529154000, 13, 12);
        addMatch(6, 1529164800, 11, 10);
        addMatch(7, 1529175600, 15, 14);
        addMatch(8, 1529236800, 19, 18);
        addMatch(9, 1529247600, 21, 20);
        addMatch(10, 1529258400, 17, 16);
        addMatch(11, 1529323200, 23, 22);
        addMatch(12, 1529334000, 24, 25);
        addMatch(13, 1529344800, 27, 26);
        addMatch(14, 1529409600, 31, 30);
        addMatch(15, 1529420400, 29, 28);
        addMatch(16, 1529431200, 2, 0);
        addMatch(17, 1529496000, 6, 4);
        addMatch(18, 1529506800, 1, 3);
    }
}
