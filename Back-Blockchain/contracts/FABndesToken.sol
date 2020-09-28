pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./RBBToken.sol";
import "./SpecificRBBToken.sol";
import "./FABndesToken_BNDESRoles.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
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

*/


contract FABndesToken is SpecificRBBToken {

    RBBToken public rbbToken;
    FABndesToken_BNDESRoles public bndesRoles;

    //RBBId donor => true/false (registered or not)
    mapping (uint => bool) public donors;

    //RBBId client => (idFinancialSupportAgreement Client => true/false (registered or not)
    mapping (uint => mapping (string => bool)) public clients;

    //RBBId supplier => true/false (registered or not)
    mapping (uint => bool) public suppliers;

    //Hash of approved Extraordinary Transfers
    bytes32[] public hashApprovedExtraordinaryTransfers;

    // BNDES Fee percentage
    uint256 public bndesFee;    

    //Types of transfer operation
    string public INITIAL_ALLOCATION = "INITIAL_ALLOCATION";
    string public DISBURSEMENT_VERIFICATION = "DISBURSEMENT_VERIFICATION";
    string public CLIENT_PAY_SUPPLIER_VERIFICATION = "CLIENT_PAY_SUPPLIER_VERIFICATION";
    string public BNDES_PAY_SUPPLIER_VERIFICATION = "BNDES_PAY_SUPPLIER_VERIFICATION";
    string public EXTRAORDINARY_TRANSFERS = "EXTRAORDINARY_TRANSFERS";


    uint8 public RESERVED_MINTED_ACCOUNT = 0;
    uint8 public RESERVED_USUAL_DISBURSEMENTS_ACCOUNT = 1;
    uint8 public RESERVED_BNDES_ADMIN_FEE_TO_HASH = 2;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_DONOR = 10;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER = 20;
    uint8 public RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY = 30;

    using SafeMath for uint;
   
    event FA_DonationBooked(uint idDonor, uint amount, bytes32 docHash);
    event FA_DonationConfirmed(uint idDonor, uint amount, bytes32 docHash);

    event FA_InitialAllocation_Disbursements(uint amount, bytes32 docHash);
    event FA_InitialAllocation_Fee(uint amount, bytes32 docHash);

    event FA_Disbursement  (uint idClient, string idFinancialSupportAgreement, uint amount, bytes32 docHash);
    event FA_TokenTransfer (uint fromCnpj, string fromIdFinancialSupportAgreement, uint toCnpj, uint amount, bytes32 docHash);
    event FA_BNDES_TokenTransfer(uint toCnpj, uint amount, bytes32 docHash);
    event FA_RedemptionRequested (uint idClaimer, uint amount, bytes32 docHash);
    event FA_RedemptionSettlement(bytes32 redemptionTransactionHash, bytes32 docHash);
 
    event FA_ExtraordinaryTransferAllowed (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);
    event FA_ExtraordinaryTransferExecuted(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, bytes32 docHash);

    event FA_ManualIntervention_Fee(uint256 percent, bytes32 docHash);

    event FA_DonorAdded(uint id);
    event FA_ClientAdded(uint id);
    event FA_SupplierAdded(uint registeredBy, uint id);


    constructor (address newrbbTokenAddr, address addrBndesRoles, uint fee) public {
        require (fee < 100, "Valor de Fee maior que 100%");

        rbbToken = RBBToken(newrbbTokenAddr);
        bndesRoles = FABndesToken_BNDESRoles(addrBndesRoles);

        bndesFee = fee;
    }


    function setBNDESFee(uint256 newBndesFee, bytes32 docHash) public onlyOwner {
        require (newBndesFee < 100, "Valor de Fee maior que 100%");
        bndesFee = newBndesFee;
        emit FA_ManualIntervention_Fee(newBndesFee, docHash);
    }


    function bookDonation(uint amount, bytes32 docHash) public whenNotPaused  {        
        
        uint idDonor = registry.getId(msg.sender);

        require (donors[idDonor], "Somente doadores podem fazer doações");
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        
        bytes32 specificHash = getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY);
        rbbToken.requestMint(specificHash, idDonor, amount, docHash);

        emit FA_DonationBooked(idDonor, amount, docHash);
    }
    
    /* confirms the donor's donation */
    function verifyAndActForMint(bytes32 specificHash, uint amount, bytes32 docHash,
        string[] memory data) public override whenNotPaused onlyRBBToken {

        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_DIFF_MONEY)==specificHash, "Erro no cálculo do hash da doação");

        string memory sidDonor = data[0];
        uint idDonor = RBBLib.stringtoUint(sidDonor);
        require (donors[idDonor], "Somente doadores podem fazer doações, registro estah incorreto");

        emit FA_DonationConfirmed(idDonor, amount, docHash);

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
            "Um CNPJ não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        if (!suppliers[toId]) {
            suppliers[toId] = true; //register the supplier
            emit FA_SupplierAdded(fromId, toId);
        }

        emit FA_TokenTransfer (fromId, idFinancialSupportAgreement, toId, amount, docHash);

    }


    function verifyAndActForTransfer_BNDES_PAY_SUPPLIER(address originalSender, uint fromId, bytes32 fromHash, 
            uint toId, bytes32 toHash, uint amount, bytes32 docHash, string[] memory data) internal whenNotPaused {

        require (originalSender == bndesRoles.responsibleForDisbursement(), 
            "Esta transação só pode ser executada pelo responsável pelo desembolso");

        require (fromId==registry.getId(owner()), "Somente o BNDES pode executar o pagamento");
        require (getCalculatedHash(RESERVED_BNDES_ADMIN_FEE_TO_HASH)==fromHash, "Erro no cálculo do hash da conta de admin do contrato especifico");
        require (getCalculatedHash(RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER)==toHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId, "Um BNDES não pode transferir token para si");

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

    
    function getCalculatedHash (uint info) public view returns (bytes32) {
        return keccak256(abi.encodePacked(info));
    }

    function getCalculatedHash (string memory info) public view returns (bytes32) {
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

        string memory idFinancialSupportAgreement = data[1];
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

    function addDonor (uint idDonor) public onlyOwner {
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        if(!donors[idDonor]) {
            donors[idDonor] = true;
            emit FA_DonorAdded(idDonor);
        }
    }


    function addClient (uint id, string memory idFinancialSupportAgreement) internal  {

        if (!clients[id][idFinancialSupportAgreement]) {
            clients[id][idFinancialSupportAgreement] = true; //register the client
            emit FA_ClientAdded(id);

        }
    }


    function addSupplier (uint id) public  {

        require (msg.sender == bndesRoles.responsibleForDisbursement(), "Esta transação só pode ser executada pelo responsável pelo desembolso");
        if (!suppliers[id]) {
            suppliers[id] = true; //register the supplier
            emit FA_SupplierAdded(registry.getId(owner()), id);
        }
    }

    function hasRoleInThisContract (uint rbbId, bytes32 hashToAccount) private returns (bool) {

        bool hasRole = false;
        if (donors[rbbId]==true) return true;

//TODO: resolver -- preciso verificar se esse id jah estah cadastrado no mapping de clients.
//        if (clients[rbbId]!=0) return true;
        if (suppliers[rbbId]==true) return true;

        uint ownerId = registry.getId(owner());
        if (ownerId == rbbId) return true;

        uint rbbTokenOwnerId = registry.getId(rbbToken.owner());
        if (rbbTokenOwnerId == rbbId) return true;

        return false;
    }

}