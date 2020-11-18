import { Injectable  } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { ConstantesService } from './ConstantesService';
import { formattedError } from '@angular/compiler';
import {ethers} from 'ethers';


@Injectable()
export class Web3Service {

    private serverUrl: string;

    private provider: any;
    private signer: any;

    //TODO : falta remover aqui e em todos os metodos abaixo
    private bndesRegistrySmartContract: any;

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


    private blockchainNetwork: string = '';
    private ethereum: any;
    private web3Instance: any;                  // Current instance of web3

    private vetorTxJaProcessadas : any[];

    private eventoRBBToken: any;
    private eventoTokenEspecifico: any;

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

                this.blockchainNetwork = data["blockchainNetwork"];
    
                this.addrContratoRBBToken = data["addrContratoRBBToken"];
                this.addrContratoESGBndesToken = data["addrContratoESGBndesToken"];
                this.addrContratoESGBndesToken_GetDataToCall = data["addrContratoESGBndesToken_GetDataToCall"];
                this.addrContratoRBBRegistry = data["addrContratoRBBRegistry"];
    
                this.abiRBBToken = data['abiRBBToken'];
                this.abiESGBndesToken = data['abiESGBndesToken'];
                this.abiESGBndesToken_GetDataToCall = data['abiESGBndesToken_GetDataToCall']; 
                this.abiRBBRegistry = data['abiRBBRegistry'];
            

                console.log("abis");
                console.log(this.abiRBBToken);

                this.intializeWeb3();
                this.inicializaQtdDecimais();

            },
            error => {
                console.log("**** Erro ao buscar constantes do front");
            });
            
    }

 
    intializeWeb3() {

        this.provider = new ethers.providers.JsonRpcProvider("http://35.239.231.134:4545/");
        this.ethereum =  window['ethereum'];
        console.log("provider ethers");
        console.log(this.provider);
/*
        if (typeof window['web3'] !== 'undefined') {
            this.ethereum =  window['ethereum'];
            this.web3 = new this.Web3(window['web3'].currentProvider);
    
        } else {
            console.log('Using HTTP node --- nao suportado');
            return; 
        }
*/

        this.signer = (new ethers.providers.Web3Provider(window["ethereum"])).getSigner();

        this.rbbTokenSmartContract = new ethers.Contract(this.addrContratoRBBToken, this.abiRBBToken, this.signer);
        this.esgBndesTokenSmartContract = new ethers.Contract(this.addrContratoESGBndesToken,this.abiESGBndesToken, this.signer);
        this.esgBndesToken_GetDataToCallSmartContract = new ethers.Contract(this.addrContratoESGBndesToken_GetDataToCall, this.abiESGBndesToken_GetDataToCall, this.provider);
        this.rbbRegistrySmartContract = new ethers.Contract(this.addrContratoRBBRegistry, this.abiRBBRegistry, this.provider);

        this.buscaNumeroBloco(this.signer);


        console.log("INICIALIZOU O WEB3 - rbbTokenSmartContract abaixo");
        console.log("rbbTokenSmartContract=");
        console.log(this.rbbTokenSmartContract);        

    }    
    //TODO: APAGAR
    async buscaNumeroBloco(signer) {
        console.log("ENDERECO i");
        const endereco = await signer.getAddress();
        console.log("ENDERECO f");
        console.log(endereco);
    }

    getBlockTimestamp(blockHash: number, fResult: any) {

//        this.web3.eth.getBlock(blockHash, fResult);

    }


    public getInfoBlockchainNetwork(): any {

        let blockchainNetworkAsString = "Localhost";
        let blockchainNetworkPrefix = "";
        if (this.blockchainNetwork=="4") {
            blockchainNetworkAsString = "Rinkeby";
            blockchainNetworkPrefix = "rinkeby."
        }
        else if (this.blockchainNetwork=="1") {
            blockchainNetworkAsString = "Mainnet";
        }
        else if (this.blockchainNetwork=="648629") {
            blockchainNetworkAsString = "RBB";
            //TODO: FALTA DEFINIR CAMINHO PARA BLOCK EXPLORER DO RBB
        }

        return {
            blockchainNetwork:this.blockchainNetwork,
            blockchainNetworkAsString:blockchainNetworkAsString,
            blockchainNetworkPrefix: blockchainNetworkPrefix,

            addrContratoRBBToken: this.addrContratoRBBToken,
            addrContratoESGBndesToken: this.addrContratoESGBndesToken,
            addrContratoRBBRegistry: this.addrContratoRBBRegistry,
        };
    }


    //fonte: https://www.xul.fr/javascript/callback-to-promise.php
    public getCurrentAccountSync() {
        return this.signer.getAddress();

    }



    conectar () {
        this.ethereum.enable();
    }

    async inicializaQtdDecimais() {
        this.decimais = await this.rbbTokenSmartContract.getDecimals();
        return this.decimais;
    }

    converteDecimalParaInteiro( _x : number ): number {
        return ( _x * ( 10 ** this.decimais ) ) ;
    }

    converteInteiroParaDecimal( _x: number ): number {    
        return ( _x / ( 10 ** this.decimais ) ) ;
    }


    ////////////////////// INICIO EVENTOS E MENSAGENS

//TODO: tirar "FA" do início do nome do evento

    async recuperaEventosAdicionaInvestidor() {
        let filter = this.esgBndesTokenSmartContract.filters.FA_InvestorAdded(null);
        let events = await this.esgBndesTokenSmartContract.queryFilter(filter);
        console.log("events recuperaEventosAdicionaInvestidor");    
        console.log(events);    
    }


    registraEventosAdicionaInvestidor(callback) {
 //       this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InvestorAdded({}, { fromBlock: 0, toBlock: 'latest' });
 //       this.eventoTokenEspecifico.watch(callback);
    }
    registraEventosAdicionaCliente(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_ClientAdded({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }    
    registraEventosAdicionaFornecedor(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_SupplierAdded({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }    

    registraEventosRegistrarInvestimento(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InvestmentBooked({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosRecebimentoInvestimento(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InvestmentConfirmed({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosAlocacaoParaDesembolso(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InitialAllocation_Disbursements({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosAlocacaoParaContaAdm(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_InitialAllocation_Fee({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosLiberacao(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_Disbursement({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosPagamentoFornecedores(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_TokenTransfer({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosBNDESPagaFornecedores(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_BNDES_TokenTransfer({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }    
    
    registraEventosResgate(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_RedemptionRequested({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

    registraEventosLiquidacaoResgate(callback) {
        this.eventoTokenEspecifico = this.esgBndesTokenSmartContract.FA_RedemptionSettlement({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoTokenEspecifico.watch(callback);
    }

 //TODO: alterar esses eventos para dashboard de intervencoes manuais. Falta incluir ESG_BndesToken_BndesRoles 
    registraEventosIntervencaoManualMintBurn(callback) {
        console.log("web3-registraEventosIntervencaoManual");        
//        this.eventoDoacao = this.bndesTokenSmartContract.ManualIntervention_MintAndBurn({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoDoacao.watch(callback);
    }
    registraEventosIntervencaoManualFee(callback) {
        console.log("web3-registraEventosIntervencaoManualFee");        
//        this.eventoDoacao = this.bndesTokenSmartContract.ManualIntervention_Fee({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoDoacao.watch(callback);
    }
    registraEventosIntervencaoManualRoleOrAddress(callback) {
        console.log("web3-registraEventosIntervencaoManual-RoleOrAddress");        
//        this.eventoDoacao = this.bndesRegistrySmartContract.ManualIntervention_RoleOrAddress({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoDoacao.watch(callback);
    }

    

    registraWatcherEventosLocal(txHashProcurado, callback) {
        let self = this;
        console.info("Callback ", callback);
        const filtro = { fromBlock: 'latest', toBlock: 'pending' }; 
        
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

    ////////////////////// FIM REGISTRY

    ////////////////////// INICIO INVESTIDOR


    async associaInvestidor(rbbID: number) {

        await this.esgBndesTokenSmartContract.addInvestor(rbbID);
    }

    async registrarInvestimento(amount: number) {
        
        console.log("Registra doacao");
        
        amount = this.converteDecimalParaInteiro(amount);     
        console.log("Amount=" + amount);
        console.log("this.FAKE_HASH)=" + this.FAKE_HASH);

        await this.esgBndesTokenSmartContract.bookInvestment(amount, this.FAKE_HASH);        
    }

    async getSpecificHash (info: number)  {
        console.log("getSpecificHash " + info);
        console.log(this.esgBndesToken_GetDataToCallSmartContract);
        let value = await this.esgBndesToken_GetDataToCallSmartContract.getCalculatedHashUint(info);
        return value;
    }


    async getBalanceRequestedToken(rbbId: number, fSuccess: any, fError: any) {
        
        console.log("vai recuperar o balanceOf de " + rbbId);
        let self = this;

        //TODO: resolver o que fazer porque não temos um saldo de investidor isolado
        let specificHash = <string> (await this.getSpecificHash(30));

        return this.rbbTokenSmartContract.balanceRequestedTokens(this.ID_SPECIFIC_TOKEN,specificHash,
            (error, valorSaldoCNPJ) => {
                if (error) fError(error);
                else fSuccess( self.converteInteiroParaDecimal( parseInt ( valorSaldoCNPJ ) ) );
            });            
    }


    async receberDoacao(rbbIDInvestor: number, amount: number, docHash: string, fSuccess: any, fError: any) {

        let contaSelecionada = await this.getCurrentAccountSync();    
        
        console.log("***** Web3Service - ReceberDoacao");
        amount = this.converteDecimalParaInteiro(amount); 
        console.log("conta selecionada=" + contaSelecionada);
        console.log("inv=" + rbbIDInvestor);
        console.log("amount=" + amount);
        console.log("addr=" + this.addrContratoESGBndesToken);

        //TODO: resolver o que fazer porque não temos um saldo de investidor isolado
        let specificHash = <string> (await this.getSpecificHash(30));

        //TODO: Trocar fake hash pelo hash
        this.rbbTokenSmartContract.mint(this.addrContratoESGBndesToken, rbbIDInvestor, specificHash, 
             amount, this.FAKE_HASH, [], { from: contaSelecionada},
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });  
    }  

    ////////////////// FIM INVESTIDOR

    ////////////////// INICIO SALDOS

    async getBalanceOf(rbbId: number, numeroContrato: number) {
        
        console.log("vai recuperar o balanceOf de " + rbbId);

        let valorToHash = numeroContrato?numeroContrato:this.RESERVED_NO_ADDITIONAL_FIELDS_TO_SUPPLIER;
        let specificHash =  <string> (await this.getSpecificHash(valorToHash));
        let valorRetornado = await this.rbbTokenSmartContract.rbbBalances(this.ID_SPECIFIC_TOKEN,rbbId,specificHash);

        return this.converteInteiroParaDecimal(valorRetornado.toNumber());

    }

    async getBalanceOfAllAccounts(rbbId: number, valorToHash: number) {
        
        console.log("vai recuperar o balanceOf all accounts de " + rbbId + " " + valorToHash);

        let specificHash =  <string> (await this.getSpecificHash(valorToHash));
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

    ////////////////// INÍCIO LIBERACAO

    async getDisbursementDataSync(nContrato: string) {
        console.log("*** getDisbursementDataSync");

        return await this.esgBndesToken_GetDataToCallSmartContract.getDisbusementData(nContrato);
    }

    async liberacao(rbbIdDestino: number, nContrato: string, transferAmount: number, fSuccess: any, fError: any) {
        console.log("Web3Service - Liberacao");

        const endereco = await this.signer.getAddress();
        console.log(endereco);

//        let contaSelecionada = await this.getCurrentAccountSync(); 
        
        let disbursementData = await this.getDisbursementDataSync(nContrato);
        console.log(disbursementData);
        let fromHash = disbursementData[0];
        console.log(fromHash);

        let toHash = disbursementData[1];
        console.log(toHash);

        let dataFromDD = disbursementData[2];
        console.log(dataFromDD);

        transferAmount = this.converteDecimalParaInteiro(transferAmount);  
        console.log('TransferAmount(after)=' + transferAmount);


//        function transfer (address specificTokenAddr, bytes32 fromHash, uint toId, bytes32 toHash, 
//            uint amount, bytes32 docHash, string[] memory data) public whenNotPaused {
        this.associaInvestidor(2);

//        this.rbbTokenSmartContract.transfer(this.ID_SPECIFIC_TOKEN, fromHash, rbbIdDestino, toHash,
//            transferAmount, this.FAKE_HASH, dataFromDD);

    }

    ////////////////// FIM LIBERACAO

    async resgata(transferAmount: number, fSuccess: any, fError: any) {

        let contaSelecionada = await this.getCurrentAccountSync();    
        
        console.log("conta selecionada=" + contaSelecionada);
        console.log("Web3Service - Redeem");
        transferAmount = this.converteDecimalParaInteiro(transferAmount);     

        this.rbbTokenSmartContract.redeem(transferAmount, { from: contaSelecionada, gas: 500000 },
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    liquidaResgate(hashResgate: any, hashComprovante: any, isOk: boolean, fSuccess: any, fError: any) {
        console.log("Web3Service - liquidaResgate")
        console.log("HashResgate - " + hashResgate)
        console.log("HashComprovante - " + hashComprovante)
        console.log("isOk - " + isOk)

        this.rbbTokenSmartContract.notifyRedemptionSettlement(hashResgate, hashComprovante, 
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }



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

    isCliente(address: string, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isClient(address,
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }
  
    isClienteSync(address: string) {
        let self = this;

        return new Promise (function(resolve) {
            self.isCliente(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO IS CLIENTE SYNC");
                reject(false);
            });
        })
    }
/* 
//TODO: avaliar se precisa incluir isso ou se consiguimos emitir o erro no metamask
    isDoador(address: string, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isDonor(address,
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    isDoadorSync(address: string) {
        let self = this;

        return new Promise (function(resolve) {
            self.isDoador(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO IS DONOR SYNC");
                reject(false);
            });
        })
    }
*/      


    async isResponsavelPorAssociarInvestidorSync () {

        let owner = await this.esgBndesTokenSmartContract.owner();
        let address = await this.signer.getAddress();
        console.log("isResponsavelPorAssociarInvestidorSync=");
        console.log(owner);

        return owner == address;
    }

/*
//TODO:
    isResponsibleForDonationConfirmation(address: string, fSuccess: any, fError: any): boolean {
        return this.esgBndesTokenSmartContract.isResponsibleForDonationConfirmation(address,
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    isResponsibleForDonationConfirmationSync(address: string) {
        let self = this;

        return new Promise (function(resolve) {
            self.isResponsibleForDonationConfirmation(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO IS responsible for Donation Confirmation  SYNC");
                reject(false);
            });
        })
    }    
*/
    isResponsibleForSettlement(address: string, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isResponsibleForSettlement(address,
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    isResponsibleForSettlementSync(address: string) {
        let self = this;

        return new Promise (function(resolve) {
            self.isResponsibleForSettlement(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO IS responsible for Settlement  SYNC");
                reject(false);
            });
        })
    }

    isResponsibleForRegistryValidation(address: string, fSuccess: any, fError: any): boolean {

        return this.bndesRegistrySmartContract.isResponsibleForRegistryValidation(address,
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    isResponsibleForRegistryValidationSync(address: string) {
        let self = this;

        return new Promise (function(resolve) {
            self.isResponsibleForRegistryValidation(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO isResponsibleForRegistryValidation  SYNC");
                reject(false);
            });
        })
    }    


    isResponsibleForDisbursement(address: any, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isResponsibleForDisbursement(address,
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    async isResponsibleForDisbursementSync() {
        let self = this;

        let contaBlockchain = await this.getCurrentAccountSync();

        return new Promise (function(resolve) {
            self.isResponsibleForDisbursement(contaBlockchain, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO isResponsibleForDisbursement  SYNC");
                reject(false);
            });
        })
    }       


}