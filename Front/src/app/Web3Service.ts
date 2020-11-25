import { Injectable  } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { ConstantesService } from './ConstantesService';
import { formattedError } from '@angular/compiler';
import {ethers} from 'ethers';


@Injectable()
export class Web3Service {

    private serverUrl: string;

    private ethereum: any;
    private provider: any;
    private accountProvider: any;

    private addrContratoRBBToken: string = '';
    private addrContratoESGBndesToken: string = '';
    private addrContratoESGBndesToken_GetDataToCall: string = '';
    private addrContratoRBBRegistry: string = '';

    private abiRBBToken: string = '';
    private abiESGBndesToken: string = '';
    private abiESGBndesToken_GetDataToCall: string = ''; 
    private abiRBBRegistry: string = '';

    private rbbTokenSmartContract: any;
    private esgBndesTokenSmartContract: any;
    private esgBndesToken_GetDataToCallSmartContract: any;
    private rbbRegistrySmartContract: any;

    private URLBlockchainExplorer: string;
    private nomeRedeBlockchain: string;
    private numeroBlockchainNetwork: string = '';
    private URLBlockchainProvider: string;

    private vetorTxJaProcessadas : any[];

    private decimais : number;

    private FAKE_HASH = ethers.constants.HashZero;

//VARIAVEIS DO SMART CONTRACT
    private ID_SPECIFIC_TOKEN: number = 1;
    private ID_BNDES: number = 1;

    private RESERVED_MINTED_ACCOUNT: number = 0; 
    private RESERVED_USUAL_DISBURSEMENTS_ACCOUNT: number = 1; 
    private RESERVED_BNDES_ADMIN_FEE_TO_HASH: number = 2;

    private RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER: number = 20;


    constructor(private http: HttpClient, private constantes: ConstantesService) {
       
        this.vetorTxJaProcessadas = [];

        this.serverUrl = ConstantesService.serverUrl;
        console.log("Web3Service.ts :: Selecionou URL = " + this.serverUrl)

        this.http.post<Object>(this.serverUrl + 'constantesFront', {}).subscribe(
            data => {

                this.numeroBlockchainNetwork = data["blockchainNetwork"];
                this.URLBlockchainExplorer = data["URLBlockchainExplorer"];
                this.URLBlockchainProvider = data["URLBlockchainProvider"];
                this.nomeRedeBlockchain = data["nomeRedeBlockchain"];
    
                this.addrContratoRBBToken = data["addrContratoRBBToken"];
                this.addrContratoESGBndesToken = data["addrContratoESGBndesToken"];
                this.addrContratoESGBndesToken_GetDataToCall = data["addrContratoESGBndesToken_GetDataToCall"];
                this.addrContratoRBBRegistry = data["addrContratoRBBRegistry"];
    
                this.abiRBBToken = data['abiRBBToken'];
                this.abiESGBndesToken = data['abiESGBndesToken'];
                this.abiESGBndesToken_GetDataToCall = data['abiESGBndesToken_GetDataToCall']; 
                this.abiRBBRegistry = data['abiRBBRegistry'];
            

                this.intializeWeb3();
                this.inicializaQtdDecimais();

            },
            error => {
                console.log("**** Erro ao buscar constantes do front");
            });
            
    }

 
    intializeWeb3() {

        console.log("#### this.URLBlockchainProvider = " + this.URLBlockchainProvider);
        this.provider = new ethers.providers.JsonRpcProvider(this.URLBlockchainProvider);
        this.ethereum =  window['ethereum'];
        console.log("provider ethers");
        console.log(this.provider);

        this.rbbTokenSmartContract = new ethers.Contract(this.addrContratoRBBToken, this.abiRBBToken, this.provider);
        this.esgBndesTokenSmartContract = new ethers.Contract(this.addrContratoESGBndesToken,this.abiESGBndesToken, this.provider);
        this.esgBndesToken_GetDataToCallSmartContract = new ethers.Contract(this.addrContratoESGBndesToken_GetDataToCall, this.abiESGBndesToken_GetDataToCall, this.provider);
        this.rbbRegistrySmartContract = new ethers.Contract(this.addrContratoRBBRegistry, this.abiRBBRegistry, this.provider);

        this.accountProvider = new ethers.providers.Web3Provider(this.ethereum);

        console.log("INICIALIZOU O WEB3 - rbbTokenSmartContract abaixo");
        console.log("accountProvider=");
        console.log(this.accountProvider);        

    } 


    async getBlockTimestamp(blockNumber: number) {

        let block = await this.provider.getBlock(blockNumber);
        return block.timestamp;

    }


    public getInfoBlockchain(): any {

        return {

            URLBlockchainExplorer: this.URLBlockchainExplorer,
            nomeRedeBlockchain: this.nomeRedeBlockchain,

            addrContratoRBBToken: this.addrContratoRBBToken,
            addrContratoESGBndesToken: this.addrContratoESGBndesToken,
            addrContratoRBBRegistry: this.addrContratoRBBRegistry,
        };
    }


    public getCurrentAccountSync() {
        return this.accountProvider.getSigner().getAddress();
    }

    conectar () {
        this.ethereum.enable();
    }

    async inicializaQtdDecimais() {
        this.decimais = await this.rbbTokenSmartContract.getDecimals();
        return this.decimais;
    }

    converteDecimalParaInteiro( _x : number ): number {
        let v = _x * ( 10 ** this.decimais);
        return ( Math.floor(v) );
    }

    converteInteiroParaDecimal( _x: number ): number {    
        return ( _x / ( 10 ** this.decimais ) ) ;
    }


    ////////////////////// INICIO EVENTOS E MENSAGENS

//TODO: tirar "FA" do início do nome do evento

    async recuperaEventosAdicionaInvestidor() {

        let filter = this.esgBndesTokenSmartContract.filters.FA_InvestorAdded(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
/*
        //TODO: avaliar se funciona para ler novos eventos
        let topic = ethers.utils.id("FA_InvestorAdded(uint id");
        filter = {
            address: this.addrContratoESGBndesToken,
            topics: [ topic ]
        };

        this.provider.on(filter, (result) => {
            console.log("dentro do evento do eethers do associa inv");
            console.log(result);
        });
*/

    }

    async recuperaEventosAdicionaCliente() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_ClientAdded(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async recuperaEventosAdicionaFornecedor() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_SupplierAdded(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async registraEventosRegistrarInvestimento() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_InvestmentBooked(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async registraEventosRecebimentoInvestimento() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_InvestmentConfirmed(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async registraEventosAlocacaoParaDesembolso() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_InitialAllocation_Disbursements(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);

    }

    async registraEventosAlocacaoParaContaAdm() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_InitialAllocation_Fee(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async registraEventosLiberacao() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_Disbursement(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async registraEventosPagamentoFornecedores() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_TokenTransfer(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async registraEventosBNDESPagaFornecedores() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_BNDES_TokenTransfer(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }    
    
    async registraEventosResgate() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_RedemptionRequested(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

    async registraEventosLiquidacaoResgate() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_RedemptionSettlement(null);
        return await this.esgBndesTokenSmartContract.queryFilter(filter);
    }

 //TODO: alterar esses eventos para dashboard de intervencoes manuais. Falta incluir ESG_BndesToken_BndesRoles 
    async registraEventosIntervencaoManualMintBurn() {
        console.log("web3-registraEventosIntervencaoManual");

    }
    
    async registraEventosIntervencaoManualFee() {
        console.log("web3-registraEventosIntervencaoManualFee");        
//TODO
    }
    async registraEventosIntervencaoManualRoleOrAddress() {
        console.log("web3-registraEventosIntervencaoManual-RoleOrAddress");        
//TODO
    }



    registraWatcherEventosLocal(txHashProcurado, callback) {
        
        let self = this;
        console.info("Callback ", callback);
        const filtro = { fromBlock: 'latest', toBlock: 'pending' }; 
/* TODO        
        this.eventoRBBToken = this.rbbTokenSmartContract.allEvents( filtro );                 
        this.eventoRBBToken.watch( function (error, result) {
            console.log("Watcher Token Genérico executando...")
            self.procuraTransacao(error, result, txHashProcurado, self, callback);
        });
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.allEvents( filtro );                 
        this.eventoTokenEspecifico.watch( function (error, result) {
            console.log("Watcher Token Específico executando...")
            self.procuraTransacao(error, result, txHashProcurado, self, callback);
        });
*/
        console.log("registrou o watcher de eventos");
        
    }

    procuraTransacao(error, result, txHashProcurado, self, callback) {
        console.log( "Entrou no procuraTransacao" );
        console.log( "txHashProcurado: " + txHashProcurado );
        console.log( "result.transactionHash: " + result.transactionHash );
        self.web3.eth.getTransactionReceipt(txHashProcurado,  function (error, result) {
            if ( !error ) {
                let status = result.status
                let STATUS_MINED = 0x1
                console.log("Achou o recibo da transacao... " + status)     
                if ( status == STATUS_MINED && !self.vetorTxJaProcessadas.includes(txHashProcurado)) {
                    self.vetorTxJaProcessadas.push(txHashProcurado);
                    callback(error, result);        
                } else {
                    console.log('"Status da tx pendente ou jah processado"')
                }
            }
            else {
              console.log('Nao eh o evento de confirmacao procurado')
            } 
        });     
    }


    ////////////////////// INICIO REGISTRY

    async getRBBIDByCNPJSync(cnpj: number) {
        let id = await this.rbbRegistrySmartContract.getIdFromCNPJ(cnpj);
        return id.toNumber();
    }    

    async getCNPJByAddressSync(addr: string) {
        let result = await this.rbbRegistrySmartContract.getRegistry(addr);
        let id = result[1];
        return id.toNumber();
    }    

    async getIdByAddressSync(addr: string) {
        let result = await this.rbbRegistrySmartContract.getRegistry(addr);
        let id = result[0];
        return id; 
    }    

    async getRegistryByAddressSync(addr: string) {
        let result = await this.rbbRegistrySmartContract.getRegistry(addr);
        let registry: {id: number, cnpj: string} 
        registry = {id: (<number>result[0]), cnpj: (<string>result[1])};
        return registry;
    }


    ////////////////////// FIM REGISTRY

    ////////////////////// INICIO INVESTIDOR


    async associaInvestidor(rbbID: number): Promise<any> {

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.esgBndesTokenSmartContract.connect(signer);
        return (await contWithSigner.addInvestor(rbbID));
    }

    async registrarInvestimento(amount: number): Promise<any> {
        
        console.log("Registra doacao!!! ");
        
        amount = this.converteDecimalParaInteiro(amount);     
        console.log("Amount=" + amount);
        console.log("this.FAKE_HASH)=" + this.FAKE_HASH);

        let amountAsBigNumber = ethers.BigNumber.from(amount);
        console.log("AmountBigN=" + amountAsBigNumber);

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.esgBndesTokenSmartContract.connect(signer);

        return (await contWithSigner.bookInvestment(amountAsBigNumber, this.FAKE_HASH));        
    }

    async getSpecificHashAsUint (info: number)  {
        
        console.log("getSpecificHashUin " + info);
        console.log(this.esgBndesToken_GetDataToCallSmartContract);
        let value = await this.esgBndesToken_GetDataToCallSmartContract.getCalculatedHashUint(info);
        
        return value;
    }

    async getSpecificHashAsString (info: string)  {
        console.log("getSpecificHashString " + info);
        console.log(this.esgBndesToken_GetDataToCallSmartContract);
        let value = await this.esgBndesToken_GetDataToCallSmartContract.getCalculatedHashString(info);
        return value;
    }


    async getBalanceRequestedToken(rbbId: number): Promise <number> {
        
        console.log("vai recuperar o balanceOf de " + rbbId);
        let self = this;

        //TODO: resolver o que fazer porque não temos um saldo de investidor isolado
        let specificHash = <string> (await this.getSpecificHashAsUint(30));

        let retornedValue = await this.rbbTokenSmartContract.balanceRequestedTokens(this.ID_SPECIFIC_TOKEN,specificHash);

        return self.converteInteiroParaDecimal( retornedValue.toNumber() );
    }


    async receberDoacao(rbbIDInvestor: number, amount: number, docHash: string): Promise<any> {
        
        console.log("***** Web3Service - ReceberDoacao 2");
        amount = this.converteDecimalParaInteiro(amount); 
        console.log("amount=" + amount);
        console.log("inv=" + rbbIDInvestor);
        console.log("addr=" + this.addrContratoESGBndesToken);

        //TODO: resolver o que fazer porque não temos um saldo de investidor isolado
        let specificHash = <string> (await this.getSpecificHashAsUint(30));

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.rbbTokenSmartContract.connect(signer);

        //TODO: Trocar fake hash pelo hash
        return (await contWithSigner.mint(this.addrContratoESGBndesToken, rbbIDInvestor, specificHash, 
            amount, this.FAKE_HASH, []));  
    }  

    ////////////////// FIM INVESTIDOR

    ////////////////// INICIO SALDOS

    async getBalanceOf(rbbId: number, numeroContrato: number) {
        
        console.log("getBalanceOf  de " + rbbId);

        let specificHash = "";
        if (numeroContrato) {
            let valorToHash = numeroContrato+"";
            specificHash =  <string> (await this.getSpecificHashAsString(valorToHash));
        }
        else {
            let valorToHash = this.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER;
            specificHash = <string> (await this.getSpecificHashAsUint(valorToHash));
        }

        console.log("specificHash= " + specificHash);

        let valorRetornado = await this.rbbTokenSmartContract.rbbBalances(this.ID_SPECIFIC_TOKEN,rbbId,specificHash);

        return this.converteInteiroParaDecimal(valorRetornado.toNumber());

    }

    async getBalanceOfAllAccounts(rbbId: number, valorToHash: number) {
        
        console.log("vai recuperar o balanceOf all accounts de " + rbbId + " " + valorToHash);

        let specificHash =  <string> (await this.getSpecificHashAsUint(valorToHash));
        let valorRetornado = await this.rbbTokenSmartContract.rbbBalances(this.ID_SPECIFIC_TOKEN,rbbId,specificHash);

        return this.converteInteiroParaDecimal(valorRetornado.toNumber());

    }

    async getMintedBalance() {

        return this.getBalanceOfAllAccounts(this.ID_BNDES, this.RESERVED_MINTED_ACCOUNT);

    }

    async getDisbursementBalance() {

        return this.getBalanceOfAllAccounts(this.ID_BNDES, this.RESERVED_USUAL_DISBURSEMENTS_ACCOUNT);

    }

    async getAdminFeeBalance() {

        return this.getBalanceOfAllAccounts(this.ID_BNDES, this.RESERVED_BNDES_ADMIN_FEE_TO_HASH);

    }

    ////////////////// FIM SALDOS

    ////////////////// INÍCIO METODOS DE TRANSFER

    async alocaRecursosDesembolso2(rbbIdBNDES: number, transferAmount: number) : Promise<any> {

        console.log("Web3Service - alocaRecursosDesembolso");

        let alocaRecursosData = await this.esgBndesToken_GetDataToCallSmartContract.getInitialAllocationToChargeFeeData();
        let fromHash = alocaRecursosData[0];
        console.log(fromHash);

        let toHash = alocaRecursosData[1];
        console.log(toHash);

        let dataFromDD = alocaRecursosData[2];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);  
        
        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.rbbTokenSmartContract.connect(signer);
 
        return (await contWithSigner.transfer(
            this.addrContratoESGBndesToken, fromHash, rbbIdBNDES, toHash,
            transferAmount, this.FAKE_HASH, dataFromDD));
    
    }
    



    async liberacao(rbbIdDestino: number, nContrato: string, transferAmount: number) : Promise<any> {
        console.log("Web3Service - Liberacao");

        let disbursementData = await this.esgBndesToken_GetDataToCallSmartContract.getDisbusementData(nContrato);
        console.log(disbursementData);
        let fromHash = disbursementData[0];
        console.log(fromHash);

        let toHash = disbursementData[1];
        console.log(toHash);

        let dataFromDD = disbursementData[2];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);  
        console.log('TransferAmount(after)=' + transferAmount);

       const signer = this.accountProvider.getSigner();
       const contWithSigner = this.rbbTokenSmartContract.connect(signer);
       
       return (await contWithSigner.transfer(
            this.addrContratoESGBndesToken, fromHash, rbbIdDestino, toHash,
            transferAmount, this.FAKE_HASH, dataFromDD));

    }

    async pagaFornecedor(nContratoOrigem: string, rbbIdDestino: number, transferAmount: number) : Promise<any> {

        console.log("Web3Service - PagarFornecedor");

        let callData = await this.esgBndesToken_GetDataToCallSmartContract.getClientPaySupplierData(nContratoOrigem);
        console.log(callData);
        let fromHash = callData[0];
        console.log(fromHash);

        let toHash = callData[1];
        console.log(toHash);

        let dataFromDD = callData[2];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);  
        console.log('TransferAmount(after)=' + transferAmount);

       const signer = this.accountProvider.getSigner();
       const contWithSigner = this.rbbTokenSmartContract.connect(signer);
       
       return (await contWithSigner.transfer(
            this.addrContratoESGBndesToken, fromHash, rbbIdDestino, toHash,
            transferAmount, this.FAKE_HASH, dataFromDD));

    }

    async resgata(transferAmount: number) {

        console.log("Web3Service - Redeem");

        let callData = await this.esgBndesToken_GetDataToCallSmartContract.getRedeemData();
        console.log(callData);
        let fromHash = callData[0];
        console.log(fromHash);

        let dataFromDD = callData[1];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);     
        console.log('TransferAmount(after)=' + transferAmount);

       const signer = this.accountProvider.getSigner();
       const contWithSigner = this.rbbTokenSmartContract.connect(signer);
       
       return (await contWithSigner.redeem (
            this.addrContratoESGBndesToken, fromHash, transferAmount, this.FAKE_HASH, dataFromDD));

    }

    async liquidaResgate(hashResgate: any, hashComprovante: any) {
        console.log("Web3Service - liquidaResgate")
        console.log("HashResgate - " + hashResgate)
        console.log("HashComprovante - " + hashComprovante)
//        console.log("isOk - " + isOk)
//TODO: Avaliar se precisa incluir o isOk --->  impacto no smart contract
        let emptyData: String[];
        emptyData = new Array<String>();

        const signer = this.accountProvider.getSigner();
        const contWithSigner = this.rbbTokenSmartContract.connect(signer);

        
        return (await contWithSigner.redeem (
                this.addrContratoESGBndesToken, hashResgate, this.FAKE_HASH, emptyData));
     
    }


    //TODO: ajustar TODOS OS metodos ABAIXO para perguntar pelo papel correto 

    /*
    getConfirmedTotalSupply(fSuccess: any, fError: any): number {

    console.log("vai recuperar o confirmedtotalsupply. " );
    let self = this;


    return this.rbbTokenSmartContract.rbbBalances[]()
        (error, confirmedTotalSupply) => {
            if (error) fError(error);
            else fSuccess( self.converteInteiroParaDecimal(  parseInt ( confirmedTotalSupply ) ) );
        });
       return -1;           
         
 
    }

*/

    async isResponsavelPorAssociarInvestidorSync () {

        let owner = await this.esgBndesTokenSmartContract.owner();
        let address = await this.accountProvider.getSigner().getAddress();
        console.log("isResponsavelPorAssociarInvestidorSync=");
        console.log(owner);

        return owner == address;
    }
  
    isClienteSync(address: string) {
        return false;
    }

    isDoadorSync(address: string) {
        return false;
    }

    isResponsibleForDonationConfirmationSync(address: string) {
        return false;
    }    

    isResponsibleForSettlementSync(address: string) {
        return false;
    }

    async isResponsibleForDisbursementSync() {
        return false;
    }       
}
