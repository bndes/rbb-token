pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;


import "./RBBLib.sol";
import "./RBBRegistry.sol";
import "./RBBToken.sol";
import "./SpecificRBBToken.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";



// Pode ter cliente no hash xyz, fornecedor no hash abc
// clientes no hash xyz são aqueles que bndes informou (set cliente no hash total)
/*
Regras específicas
- Toda vez que o BNDES faz um desembolso, o destinatário será associado como CLIENTE para um idFinancialSupportAgreement específico (se ainda não estiver associado).
- Somente clientes fazem pagamentos. Toda vez que um CLIENTE de um idFinancialSupportAgreement específico paga um fornecedor, o destinatário será associado como FORNECEDOR (se ainda não estiver associado). 
- Somente FORNECEDORES podem solicitar o resgate.

Todas as operações já supõem que a entidade de origem e destino estão cadastradas e validadas, pois isso é garantido pelo contrato genérico (RBB_Token)

Não incluído:
------------
- requisito adicional de o cliente poder resgatar uma parte do valor
- possibilidade de devolução de valores
    - pode ocorrer no final do contrato, por exemplo, porque sobrou algum valor
    - pode ocorrer no meio do contrato (glosa) e  normalmente se resolve aprovando uma comprovação da devolução para a conta bancária do projeto, sem precisar devolver ao BNDES. Mas tem alguns casos de devolução ao BNDES no meio do contrato, que ocorre em casos mais graves, e quando se quer ter mais controle sobre o uso do recurso
- ideia de o fornecedor poder sacar mais de um saldo ao mesmo tempo.

- qualquer pessoa do BNDES pode liberar (não é necessário verificar na blockchain)
*/

//TODO: teoricamente, o cliente deveria registrar na blockchain o pedido de financiamento do cliente, concordam?

contract FABndesToken is SpecificRBBToken {

    //RBBId donor => true/false (registered or not)
    mapping (uint => bool) donors;

    //RBBId client => (idFinancialSupportAgreement Client => true/false (registered or not)
    mapping (uint => mapping (string => bool)) public clients;

    //RBBId supplier => true/false (registered or not)
    mapping (uint => bool) suppliers;

   /* Hash of approved ManualInterventionOperationApprovedByOwner */
    bytes32[] public hashManualInterventionOperationApprovedByOwner;


   /* BNDES Fee percentage */
    uint256 public bndesFee;    

    string public DISBURSEMENT_VERIFICATION = "DISBURSEMENT_VERIFICATION";
    string public PAY_SUPPLIER_VERIFICATION = "PAY_SUPPLIER_VERIFICATION";

//precisa ser uma em especial ou pode ficar no mesmo bolo das intervencoes manuais?
//    string public RETURN_FROM_CLIENT_TO_BNDES_VERIFICATION = "RETURN_FROM_CLIENT_TO_BNDES_VERIFICATION";

    string public MANUAL_INTERVENTION = "MANUAL_INTERVENTION";

    address public responsibleForDonationConfirmation;
    address public responsibleForDisbursement;
    address public resposibleForExtraordinaryTransfers;
    address public responsibleForSettlement;

    uint8 public RESERVED_NO_ADDITIONAL_FIELD_TO_HASH = 0;

     using SafeMath for uint;
   

//TODO: rever eventos para BNDES Transparente
    event FA_Disbursement  (uint idClient, string idFinancialSupportAgreement, uint amount);
    event FA_TokenTransfer (uint fromCnpj, string fromIdFinancialSupportAgreement, uint toCnpj, uint amount);
    event FA_RedemptionRequested (uint idClaimer, uint amount);
    event FA_RedemptionSettlement(string redemptionTransactionHash, string receiptHash);

    event FA_DonationBooked(uint idDonor, uint amount);
    event FA_DonationConfirmed(string idDonor, uint amount, string receiptHash);
    event FA_AdmFeeCharged(string idDonor, uint amount);

 //   event FAB_ManualIntervention_Returned_Client_BNDES (uint fromId, string idFinancialSupportAgreement, uint amount);
    event FA_ManualIntervention_Fee(uint256 percent, string description);

    event ManualIntervention_RoleOrAddress(address account, uint8 eventType);
    event FA_DonorAdded(uint id);
    event FA_ClientAdded(uint id);
    event FA_SupplierAdded(uint id);

//TODO: verificar papeis nos metodos abaixo
    constructor (uint fee) public {
        require (fee < 100, "Valor de Fee maior que 100%");

        responsibleForDonationConfirmation = msg.sender;
        responsibleForDisbursement = msg.sender;
        resposibleForExtraordinaryTransfers = msg.sender;
        responsibleForSettlement = msg.sender;

        bndesFee = fee;
    }


    function setBNDESFee(uint256 newBndesFee, string memory description) public onlyOwner {
        require (newBndesFee < 100, "Valor de Fee maior que 100%");
        bndesFee = newBndesFee;
        emit FA_ManualIntervention_Fee(newBndesFee, description);
    }

    function addDonor (uint idDonor) public onlyOwner {
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        if(!donors[idDonor]) {
            donors[idDonor] = true;
            emit FA_DonorAdded(idDonor);
        }
    }

    /* Donor books a donation */
    function bookDonation(uint amount) public whenNotPaused  {        
        
        uint idDonor = registry.getId(msg.sender);

        require (donors[idDonor], "Somente doadores podem fazer doações");
        require(registry.isValidatedId(idDonor), "Conta de doador precisa estar com cadastro validado");
        
        bytes32 specificHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));
        rbbToken.requestMint(specificHash, idDonor, amount);

        emit FA_DonationBooked(idDonor, amount);
    }
    
    /* confirms the donor's donation */
    function verifyAndActForMint(bytes32 specificHash, uint amount, string[] memory data,
        string memory docHash) public whenNotPaused onlyRBBToken {

        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==specificHash, "Erro no cálculo do hash da doação");

        uint admFee = amount.mul(bndesFee).div(100);
        rbbToken.burn(admFee);

        string memory idDonor = data[0];
//        require (donors[idDonor], "Somente doadores podem fazer doações, registro estah incorreto");

//TODO: transformar de string para uint de forma a ter eventos soh com uint
        emit FA_DonationConfirmed(idDonor, amount, docHash);
        emit FA_AdmFeeCharged(idDonor, amount);

    }

    //*********** */


    function getDisbusementData (string memory idFinancialSupportAgreement) public view
        returns (bytes32, bytes32, string[] memory)  {

        bytes32 fromHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));
        bytes32 toHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));

        string[] memory data = new string[](2);
        data[0] = DISBURSEMENT_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }

    function getPaySupplierData (string memory idFinancialSupportAgreement) public view
            returns (bytes32, bytes32, string[] memory) {

        bytes32 fromHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));
        bytes32 toHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));

        string[] memory data = new string[](2);
        data[0] = PAY_SUPPLIER_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }


    function getRedeemData () public 
            returns (bytes32, string[] memory) {

        bytes32 fromHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));

        string[] memory data = new string[](0);
        return (fromHash, data);
    }

    //*********** */


    function verifyAndActForTransfer(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) public whenNotPaused onlyRBBToken {

        string memory specificMethod = data[0];

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");


        if (RBBLib.isEqual(DISBURSEMENT_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_DISBURSEMENT(fromId, fromHash, toId, toHash, amount, data);
        }
        else if (RBBLib.isEqual(PAY_SUPPLIER_VERIFICATION, specificMethod)) {
            verifyAndActForTransfer_PAY_SUPPLIER(fromId, fromHash, toId, toHash, amount, data);
        }
//TODO: incluir intervencao manual. Owner do contrato aprova uma transferencia e o dono da carteira a executa?
        else {
            require (false, "Nenhuma verificação específica encontrada para a transferência");
        }

    }

//TODO: incluir msg.sender aqui e testar que é o resposibleForSettlement
//TODO: temos que contemplar pedido de doacao!? Cliente se cadastrando no cadastro. Marcio nao acha critico
//PREMISSA 1: 
    function verifyAndActForTransfer_DISBURSEMENT(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];
        uint ownerId = registry.getId(owner());

        //Essa eh uma regra especifica visto que outra organizacao pode ter recebido o token no allocate.
        require (fromId == ownerId, "Responsável pela liberação de recursos não está correto");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do BNDES");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==toHash, "Erro no cálculo do hash da conta do cliente");

        if (!clients[toId][idFinancialSupportAgreement]) {
            clients[toId][idFinancialSupportAgreement] = true; //register the client
            emit FA_ClientAdded(toId);

        }

        emit FA_Disbursement (toId, idFinancialSupportAgreement, amount);

    }

    function verifyAndActForTransfer_PAY_SUPPLIER(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        require (clients[fromId][idFinancialSupportAgreement], "Somente clientes em contratos cadastrados podem executar o pagamento");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==fromHash, "Erro no cálculo do hash da conta do cliente");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do fornecedor");

        require(fromId != toId,
            "Um CNPJ não pode transferir token para si, ainda que em papéis distintos (Cliente/Fornecedor)");

        if (!suppliers[toId]) {
            suppliers[toId] = true; //register the supplier
            emit FA_SupplierAdded(fromId);
        }

        emit FA_TokenTransfer (fromId, idFinancialSupportAgreement, toId, amount);

    }

    //TODO: BNDES poder pagar fornecedor usando token


    function verifyAndActForRedeem(uint fromId, bytes32 fromHash, uint amount, string[] memory data) 
        public whenNotPaused onlyRBBToken {

        require (amount>0, "Valor a ser transacionado deve ser maior do que zero.");
        require (suppliers[fromId], "Somente fornecedores podem executar o pagamento");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do fornecedor");

        emit FA_RedemptionRequested (fromId, amount);

    }

    function verifyAndActForRedemptionSettlement(string memory redemptionTransactionHash, string memory receiptHash, 
        string[] memory data)
        public whenNotPaused onlyRBBToken {

        emit FA_RedemptionSettlement (redemptionTransactionHash, receiptHash);
    }

    modifier onlyRBBToken() {
        require (msg.sender==address(rbbToken), "Esse método só pode ser chamado pelo RBB_Token");
        _;
    }

    
    //*********** MANUAL INTERVENTION  */

    function authorizeExtraordinaryTransfer (uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount) public onlyOwner {
        
        //TODO: verificar from e to sao parte do contrato especifico

        bytes32 m = keccak256(abi.encodePacked(fromId, fromHash, toId, toHash, amount));
        hashManualInterventionOperationApprovedByOwner.push(m);

        //TODO: incluir evento
        //TODO: criar acao intervencao manual
    }
   
/*
    function getReturnedClientToBNDESData (string memory idFinancialSupportAgreement) public 
        returns (bytes32, bytes32, string[] memory) {

        bytes32 fromHash = keccak256(abi.encodePacked(idFinancialSupportAgreement));
        bytes32 toHash = keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH));

        string[] memory data = new string[](2);
        data[0] = RETURN_FROM_CLIENT_TO_BNDES_VERIFICATION;
        data[1] = idFinancialSupportAgreement;
        return (fromHash, toHash, data);
    }
*/   

/*    
//TODO: incluir no metodo publico, tratar como caso geral de tratamento de erros ou nao?
    function verifyAndActForTransfer_RETURN_CLIENT_BNDES(uint fromId, bytes32 fromHash, uint toId, bytes32 toHash, 
            uint amount, string[] memory data) internal whenNotPaused {
    
        string memory idFinancialSupportAgreement = data[1];

        require (clients[fromId][idFinancialSupportAgreement], "Somente clientes em contratos cadastrados podem executar o retorno de recursos");
        require (keccak256(abi.encodePacked(idFinancialSupportAgreement))==fromHash, "Erro no cálculo do hash da conta do cliente");
        require (keccak256(abi.encodePacked(RESERVED_NO_ADDITIONAL_FIELD_TO_HASH))==fromHash, "Erro no cálculo do hash da conta do BNDES");

        emit FA_ManualIntervention_Returned_Client_BNDES (fromId, idFinancialSupportAgreement, amount);

    }
*/



 /**
    * By default, the owner is also the Responsible for Donation Confirmation. 
    * The owner can assign other address to be the Responsible for Donation Confirmation. 
    * @param rs Ethereum address to be assigned as Responsible for Donation Confirmation.
    */
    function setResponsibleForDonationConfirmation(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner), "O responsável pela confirmação doação deve ser da mesmo RBB_ID do contrato");
        responsibleForDonationConfirmation = rs;
        emit ManualIntervention_RoleOrAddress(rs, 1);
    }

   /**
    * By default, the owner is also the Responsible for Disbursment. 
    * The owner can assign other address to be the Responsible for Disbursment. 
    * @param rs Ethereum address to be assigned as Responsible for Disbursment.
    */
    function setResponsibleForDisbursement(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner), "O responsável pelo desembolso deve ser da mesmo RBB_ID do contrato");
        responsibleForDisbursement = rs;
        emit ManualIntervention_RoleOrAddress(rs, 2);
    }

   /**
    * By default, the owner is also the Responsible for Extraordinary Transfers. 
    * The owner can assign other address to be the Resposible Extraordinary Transfers. 
    * @param rs Ethereum address to be assigned as Responsible for Extraordinary Transfers.
    */
    function resposibleForExtraordinaryTransfers(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner), "O responsável pelo cadastramento de transferencias extraordinárias deve ser da mesmo RBB_ID do contrato");
        resposibleForExtraordinaryTransfers = rs;
        emit ManualIntervention_RoleOrAddress(rs, 3);
    }

   /**
    * By default, the owner is also the Responsible for Settlement. 
    * The owner can assign other address to be the Responsible for Settlement. 
    * @param rs Ethereum address to be assigned as Responsible for Settlement.
    */
    function setResponsibleForSettlement(address rs) onlyOwner public {
        uint id = registry.getId(rs);
        require(id==registry.getId(owner), "O responsável pela liquidação deve ser da mesmo RBB_ID do contrato");
        responsibleForSettlement = rs;
        emit ManualIntervention_RoleOrAddress(rs, 4);
    }

/*

(2) O método que faz a confirmação da doação faz queima 3% do valor recebido. É isso mesmo ou prefere transferir os 3% para uma conta do BNDES naquele contrato + viabilizar a possibilidade de o BNDES pagar seus fornecedores? Qual a melhor solução para agora? @Marcio Onodera Bndes 
(3)  Todos os métodos poderão receber hashs de informações offchain, correto? BookDonation, transfer, etc?
(4) Faz sentido existir uma ação de burn não associada a outro evento, como um Redeem?
(5) É necessário separar o cadastro de uma empresa do papel cliente em um contrato financeiro (nesse caso, a empresa se auto-cadastraria para esse contrato financeiro) ou podemos simplificar e dizer que o cadastro ocorre no contexto de um desembolso? Percebam que com o novo RBB_Id, não temos mais a afirmação do cliente associada ao contrato financeiro. No entanto, o BNDES possui documentos no mundo offchain que o enquadram como cliente e, por isso, poderíamos simplificar permitir que o cliente fosse adicionado durante uma operação de desembolso.


2. Acho que, simplesmente, queimar não é mesmo bom, não. O dinheiro foi parar em algum lugar e esse lugar tinha que ser transparente! Aliás, o contrato específico sequer deveria poder fazer isso, pensando melhor, né? Isso talvez mude algumas coisas, não?
3. Todos? Os que precisarem de comprovação... Não está claro para mim que todos precisam. Só olhando com mais detalhes.
4. A ser executada por quem? Ele vai queimar dinheiro que está com quem? Se for dinheiro que está na conta do BNDES, pode ser razoável, embora não saiba para que isso sirva, a princípio. 
5. Não saquei, mas é coisa do token específico, não é?



2. Deveria mintar os 100% e separar os 3% para a reserva para gastos administrativos. O BNDES deveria decidir se queima tudo no início (passei para a minha reserva e ponto), queima à medida que vai pagando despesas em FIAT e se explica offchain, ou passa a pagar seus fornecedores com Token tb.
3. Bom, o hash é para incorporar á blockchain uma informação ou um conjunto de informações relativas a eventos ou documentos offcain, certo? Acho que pode haver elementos desses que não pensamos em documentar, associados a esses métodos e que, com esse artifício, pudessem enriquecer o processo.
4. Acho que sim. Talvez seja isso a ser feito, pensando no que deveria seria feito caso o BNDES tivesse que devolver o dinheiro não utilizado para os doadores do Fundo Amazônia, por exemplo. Acho q pode acontecer de devolver os fundos para outros casos tb, como o BNDES devolve está devolvendo ao FAT agora.
5. Tenho receio de não ter entendido direito o impacto da decisão, mas fica a questão que é necessário associar o cliente, ao contrato e ao desembolso. Entendo que a associação é necessriamente prévia, mas se ela será on-chain ou receberá essa garantia de outro sistema externo, creio que o efeito é o mesmo se não houver risco de trasnferência indevida.


Criar um hash específico para representar o valor dos 3%
*/


}