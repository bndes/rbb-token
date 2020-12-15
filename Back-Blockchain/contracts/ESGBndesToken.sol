pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./RBBToken.sol";
import "./SpecificRBBToken.sol";
import "./ESGBndesToken_BNDESRoles.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


/*
Todas as operações já supõem que a entidade de origem e destino estão cadastradas e validadas no RBB_Registry, pois isso é garantido pelo contrato genérico (RBB_Token)
Não incluído (TBD):
------------
- requisito adicional de o cliente poder resgatar uma parte do valor (ao invés de ter que necessariamente transferir tudo ao fornecedor)
- ideia de o fornecedor poder sacar mais de um saldo ao mesmo tempo.
- pedido inicial de financiamento do cliente 
- devolução de fornecedor para cliente sem anuência para o BNDES
- controle que cada doacao realmente se transformou em duas transacoes, uma para a conta adm e outra para a conta usual
uint admFee = amount.mul(bndesFee).div(100);
- período de validade para as autorizações de transferências extraordinárias
- invalidar doador, cliente e fornecedor (por exemplo, em caso de CNPJ deixar de existir, contrato com BNDES acabar ou periodicamente)
- permitir criar perfis diferenciados para contas dos clientes e fornecedores
- incluir possibilidade de remover doadores, clientes e, talvez, fornecedores
*/
contract ESGBndesToken is SpecificRBBToken {

    RBBToken public rbbToken;
    ESGBndesToken_BNDESRoles public bndesRoles;

    //RBBId investor => true/false (registered or not)
    mapping (uint => bool) public investors;

    //RBBId client => (idFinancialSupportAgreement Client => true/false (registered or not)
    mapping (uint => mapping (string => bool)) public clients;
    mapping (bytes32 => string) public hashToIdFinancialSupportAgreement;

    //RBBId supplier => true/false (registered or not)
    mapping (uint => bool) public suppliers;

    //Hash of approved Extraordinary Transfers
    bytes32[] public hashApprovedExtraordinaryTransfers;

    // BNDES Fee percentage
//   uint256 public bndesFee;    

    //Types of transfer operation
    string public INITIAL_ALLOCATION = "INITIAL_ALLOCATION";
    string public DISBURSEMENT_VERIFICATION = "DISBURSEMENT_VERIFICATION";
    string public CLIENT_PAY_SUPPLIER_VERIFICATION = "CLIENT_PAY_SUPPLIER_VERIFICATION";
    string public BNDES_PAY_SUPPLIER_VERIFICATION = "BNDES_PAY_SUPPLIER_VERIFICATION";
    string public EXTRAORDINARY_TRANSFERS = "EXTRAORDINARY_TRANSFERS";


    uint8 public RESERVED_MINTED_ACCOUNT = 0;
    uint8 public RESERVED_USUAL_DISBURSEMENTS_ACCOUNT = 1;
    uint8 public RESERVED_BNDES_ADMIN_FEE_TO_HASH = 2;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_INVESTOR = 10;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER = 20;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY = 30;

    using SafeMath for uint;
   
    event FA_InvestmentBooked(uint idInvestor, uint amount, bytes32 docHash);
    event FA_InvestmentConfirmed(uint idInvestor, uint amount, bytes32 docHash);

    event FA_InitialAllocation_Disbursements(uint amount, bytes32 docHash);
    event FA_InitialAllocation_Fee(uint amount, bytes32 docHash);

    event FA_Disbursement  (uint idClient, string idFinancialSupportAgreement, uint amount, bytes32 docHash);
    event FA_TokenTransfer (uint fromId, string fromIdFinancialSupportAgreement, uint toId, uint amount, bytes32 docHash);
    event FA_BNDES_TokenTransfer(uint toId, uint amount, bytes32 docHash);
    event FA_RedemptionRequested (uint idClaimer, uint amount, bytes32 docHash);
    event FA_RedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash);
 
    event FA_ExtraordinaryTransferAllowed (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);
    event FA_ExtraordinaryTransferExecuted(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);

//    event FA_ManualIntervention_Fee(uint256 percent, bytes32 docHash);

    event FA_InvestorAdded(uint id);
    event FA_ClientAdded(uint id);
    event FA_SupplierAdded(uint registeredBy, uint id);


    constructor (address newrbbTokenAddr, address addrBndesRoles) public {
//        require (fee < 100, "Valor de Fee maior que 100%");

        rbbToken = RBBToken(newrbbTokenAddr);
        bndesRoles = ESGBndesToken_BNDESRoles(addrBndesRoles);

//        bndesFee = fee;
    }

/*
    function setBNDESFee(uint256 newBndesFee, bytes32 docHash) public onlyOwner {
        require (newBndesFee < 100, "Valor de Fee maior que 100%");
        bndesFee = newBndesFee;
        emit FA_ManualIntervention_Fee(newBndesFee, docHash);
    }
*/

    function bookInvestment(uint amount, bytes32 docHash) public whenNotPaused  {        
        
        uint idInvestor = registry.getId(msg.sender);

        require (investors[idInvestor], "Somente investidores cadastrados podem executar essa ação");
 //       require(registry.isRegistryOperational(idInvestor), "Conta de investidor precisa estar com cadastro validado");
        
        bytes32 specificHash = getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY);
        rbbToken.requestMint(specificHash, idInvestor, amount, docHash);

        emit FA_InvestmentBooked(idInvestor, amount, docHash);
    }
    
    function verifyAndActForMint(uint idInvestor, bytes32 specificHash, uint amount, bytes32 docHash,
        string[] memory data) public override whenNotPaused onlyRBBToken {

        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY)==specificHash, "Erro no cálculo do hash da doação");

        require (investors[idInvestor], "Deveria ser um investidor, registro estah incorreto");

        emit FA_InvestmentConfirmed(idInvestor, amount, docHash);

    }


    function getHashToMintedAccount(bytes32 specificHash) override public returns (bytes32) {
        //There is no difference of specificHash, all money should be minted in the same account
        return getCalculatedHash(RESERVED_MINTED_ACCOUNT);
    }

    function verifyAndActForTransfer(address originalSender, uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash, string[] memory data) public override whenNotPaused onlyRBBToken {

        string memory specificMethod = data[0];

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");

        if (RBBLib.isEqual(INITIAL_ALLOCATION, specificMethod)) {
            verifyAndActForTransfer_INITIAL_ALLOCATION(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else if (RBBLib.isEqual(DISBURSEMENT_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_DISBURSEMENT(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else if (RBBLib.isEqual(CLIENT_PAY_SUPPLIER_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_CLIENT_PAY_SUPPLIER(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else if (RBBLib.isEqual(BNDES_PAY_SUPPLIER_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_BNDES_PAY_SUPPLIER(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else if (RBBLib.isEqual(EXTRAORDINARY_TRANSFERS, specificMethod)) {
            verifyAndActForTransfer_EXTRAORDINARY_TRANSFERS(originalSender, fromId, fromHash, toId, toHash, amount, docHash, data);
        }
        else {
            require (false, "Nenhuma verificação específica encontrada para a transferência");
        }

    }

    function verifyAndActForTransfer_INITIAL_ALLOCATION(address originalSender, uint fromId, bytes32 fromHash, uint toId, 
            bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {

        require (bndesRoles.responsibleForInitialAllocation() == originalSender, 
            "Somente um responsável pelas alocações iniciais pode enviar a transação");

        uint ownerId = registry.getId(owner());
        require (fromId == ownerId, "Id de origem da transação não está igual ao do owner do contrato");
        require (fromHash == getCalculatedHash(RESERVED_MINTED_ACCOUNT), "Hash de origem da transação não está correto");

        require (fromId == toId, "Id de destino da transação não está igual ao do owner do contrato");

        if (toHash == getCalculatedHash(RESERVED_USUAL_DISBURSEMENTS_ACCOUNT)) {
            emit FA_InitialAllocation_Disbursements(amount, docHash);
        }
        else if (toHash == getCalculatedHash(RESERVED_BNDES_ADMIN_FEE_TO_HASH)) {
            emit FA_InitialAllocation_Fee(amount, docHash);
        }
        else {
            require (false, "Hash de destino não está correspondente a conta de desembolso ou de adm");
        }
    }

    function verifyAndActForTransfer_DISBURSEMENT(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];
        uint ownerId = registry.getId(owner());

        require (originalSender == bndesRoles.responsibleForDisbursement(), 
            "Esta transação só pode ser executada pelo responsável pelo desembolso");

        //Essa eh uma regra especifica visto que outra organizacao pode ter recebido o token no allocate.
        require (fromId == ownerId, "Id de origem da transação não está igual ao do owner do contrato");
        require (getCalculatedHash(RESERVED_USUAL_DISBURSEMENTS_ACCOUNT)==fromHash, "Erro no cálculo do hash da conta do BNDES");
        require (getCalculatedHash(idFinancialSupportAgreement)==toHash, "Erro no cálculo do hash da conta do cliente");

        addClient(toId, idFinancialSupportAgreement);

        emit FA_Disbursement (toId, idFinancialSupportAgreement, amount, docHash);

    }   

    function verifyAndActForTransfer_CLIENT_PAY_SUPPLIER(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        //nao verifica o sender, dado que o esse contrato nao diferencia as contas do cliente

        require (clients[fromId][idFinancialSupportAgreement], "Somente clientes em contratos cadastrados podem executar o pagamento");
        require (getCalculatedHash(idFinancialSupportAgreement)==fromHash, "Erro no cálculo do hash da conta do cliente");
        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER)==toHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId,
            "Um instituição não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        addSupplier (fromId, toId);

        emit FA_TokenTransfer (fromId, idFinancialSupportAgreement, toId, amount, docHash);

    }

    function verifyAndActForTransfer_BNDES_PAY_SUPPLIER(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {
        require (fromId==registry.getId(owner()), "Somente o BNDES pode executar o pagamento");
        require (originalSender == bndesRoles.resposibleForPayingBNDESSuppliers(), 
            "Esta transação só pode ser executada pelo responsável pelo do pagamento de fornecedores do BNDES");
        require (getCalculatedHash(RESERVED_BNDES_ADMIN_FEE_TO_HASH)==fromHash, "Erro no cálculo do hash da conta de admin do contrato especifico");
        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER)==toHash, "Erro no cálculo do hash da conta do fornecedor");
        require(fromId != toId, "Um BNDES não pode transferir token para si");

        addSupplier (fromId, toId);

        emit FA_BNDES_TokenTransfer (toId, amount, docHash);

    }



    function verifyAndActForRedeem(address originalSender, uint fromId, bytes32 fromHash, uint amount, 
        bytes32 docHash, string[] memory data) public override whenNotPaused onlyRBBToken {

        //nao verifica o sender, dado que o esse contrato nao diferencia as contas do fornecedor

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        require (suppliers[fromId], "Somente fornecedores podem executar o pagamento");
        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER)==fromHash, "Erro no cálculo do hash da conta do fornecedor");

        emit FA_RedemptionRequested (fromId, amount, docHash);

    }

    function verifyAndActForRedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash, 
        string[] memory data)
        public override whenNotPaused onlyRBBToken {

        emit FA_RedemptionSettlement (redemptionTransactionHash, docHash);
    }

    modifier onlyRBBToken() {
        require (msg.sender==address(rbbToken), "Esse método só pode ser chamado pelo RBB_Token");
        _;
    }

    
    function getCalculatedHash (uint info) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }

    function getCalculatedHash (string memory info) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }

    function authorizeExtraordinaryTransfer (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
                uint amount, bytes32 docHash) public  {
        
        require (bndesRoles.resposibleForApproveExtraordinaryTransfers() == msg.sender, 
            "Somente um responsável pelas transferências extraordinárias por enviar a transação");  
        require (hasRoleInThisContract(fromId, fromHash), "Endereço de origem não incluído como papel nesse cadastro");
        require (hasRoleInThisContract(toId, toHash), "Endereço de destino não incluído como papel nesse cadastro");

        bytes32 m = keccak256(abi.encodePacked(fromId, fromHash, toId, toHash, amount));
        hashApprovedExtraordinaryTransfers.push(m);

        emit FA_ExtraordinaryTransferAllowed (fromId, fromHash, toId, toHash, amount, docHash);

    }
   
    function verifyAndActForTransfer_EXTRAORDINARY_TRANSFERS(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {

        require (hasRoleInThisContract(fromId, fromHash), "Endereço de origem não incluído como papel nesse cadastro");
        require (hasRoleInThisContract(toId, toHash), "Endereço de destino não incluído como papel nesse cadastro");

        bytes32 m = keccak256(abi.encodePacked(fromId, fromHash, toId, toHash, amount));

        bool transferApproved = false;
        uint index = 0;
        for (; index<hashApprovedExtraordinaryTransfers.length; index++) {
            if (hashApprovedExtraordinaryTransfers[index] == m) {
                transferApproved = true;
                break;
            }
        }

        require (transferApproved, "Intervenção manual não previamente cadastrada");

        hashApprovedExtraordinaryTransfers[index] 
            = hashApprovedExtraordinaryTransfers [hashApprovedExtraordinaryTransfers.length-1];
        hashApprovedExtraordinaryTransfers.pop();

        emit FA_ExtraordinaryTransferExecuted (fromId, fromHash, toId, toHash, amount, docHash);

    }

//////////
    function addInvestor (uint idInvestor) public onlyOwner {
        require(registry.isRegistryOperational(idInvestor), "Conta de investidor precisa estar com cadastro validado");
        require(!investors[idInvestor], "Investidor já cadastrado");
        investors[idInvestor] = true;
        emit FA_InvestorAdded(idInvestor);
    }

    function addClient (uint id, string memory idFinancialSupportAgreement) internal  {

        if (!clients[id][idFinancialSupportAgreement]) {
            clients[id][idFinancialSupportAgreement] = true; //register the client
            bytes32 h = getCalculatedHash(idFinancialSupportAgreement);
            hashToIdFinancialSupportAgreement[h] = idFinancialSupportAgreement;
            emit FA_ClientAdded(id);

        }
    }


    function addSupplier (uint registererId, uint idSupplier) internal  {

        if (!suppliers[idSupplier]) {
            suppliers[idSupplier] = true; //register the supplier
            emit FA_SupplierAdded(registererId, idSupplier);
        }
    }

    function hasRoleInThisContract (uint rbbId, bytes32 hashToAccount) private view returns (bool) {

        if (investors[rbbId]==true) return true;

        string memory idFinancialSupportAgreement = hashToIdFinancialSupportAgreement[hashToAccount];
        if (clients[rbbId][idFinancialSupportAgreement]==true) return true;

        if (suppliers[rbbId]==true) return true;

        uint ownerId = registry.getId(owner());
        if (ownerId == rbbId) return true;

        uint rbbTokenOwnerId = registry.getId(rbbToken.owner());
        if (rbbTokenOwnerId == rbbId) return true;

        return false;
    }

}
