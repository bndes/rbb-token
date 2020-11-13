import { Injectable  } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { ConstantesService } from './ConstantesService';
import { formattedError } from '@angular/compiler';

@Injectable()
export class Web3Service {

    private serverUrl: string;

    //TODO : falta remover aqui e em todos os metodos abaixo
    private bndesTokenSmartContract: any;
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

//    private vetorTxJaProcessadas : any[];

    private eventoRBBToken: any;

    private eventoPapeis: any;
    private eventoInvestimento: any;
    private eventoTransacao: any;

    private addressOwner: string;

    private decimais : number;

    private FAKE_HASH: number= 0;

    constructor(private http: HttpClient, private constantes: ConstantesService) {
       
//        this.vetorTxJaProcessadas = [];

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
        let self = this;
        return new Promise(function(resolve, reject) {
            self.web3.eth.getAccounts(function(error, accounts) {
                resolve(accounts[0]);
            })
        })
    }


    private intializeWeb3(): void {

        if (typeof window['web3'] !== 'undefined') {
            this.ethereum =  window['ethereum'];
            console.log("ethereum=");
            console.log(this.ethereum);
            this.web3 = new this.Web3(window['web3'].currentProvider);
            console.log("Conectado com noh");
    
        } else {
            console.log('Using HTTP node --- nao suportado');
            return; 
        }

        this.rbbTokenSmartContract = this.web3.eth.contract(this.abiRBBToken).at(this.addrContratoRBBToken);
        this.esgBndesTokenSmartContract = this.web3.eth.contract(this.abiESGBndesToken).at(this.addrContratoESGBndesToken);
        this.esgBndesToken_GetDataToCallSmartContract = this.web3.eth.contract(this.abiESGBndesToken_GetDataToCall).at(this.addrContratoESGBndesToken_GetDataToCall);
        this.rbbRegistrySmartContract = this.web3.eth.contract(this.abiRBBRegistry).at(this.addrContratoRBBRegistry);

        console.log("INICIALIZOU O WEB3 - rbbTokenSmartContract abaixo");
        console.log("rbbTokenSmartContract=");
        console.log(this.rbbTokenSmartContract);        

        let self = this;

        this.getAddressOwner(function (addrOwner) {
            console.log("Owner Addr =" + addrOwner);
            self.addressOwner = addrOwner;
        }, function (error) {
            console.log("Erro ao buscar owner=" + error);
        });

}

    conectar () {
        this.ethereum.enable();
    }

    get web3(): any {
        if (!this.web3Instance) {
            this.intializeWeb3();
        }
        return this.web3Instance;
    }
    set web3(web3: any) {
        this.web3Instance = web3;
    }
    get Web3(): any {
        return window['Web3'];
    }

    inicializaQtdDecimais() {

        let self = this;

        this.rbbTokenSmartContract.getDecimals(
            (error, result) => {
                if (error) { 
                    console.log( "Decimais error: " +  error);  
                    self.decimais = -1 ;
                } 
                else {
                    console.log ( "Decimais result: " +  result );
                    //console.log ( "Decimais .c[0]: " +  result.c[0] );
                    //self.decimais = result.c[0] ;
                    self.decimais = result;
                }
                    
            }); 

    }

    converteDecimalParaInteiro( _x : number ): number {
        return ( _x * ( 10 ** this.decimais ) ) ;
    }

    converteInteiroParaDecimal( _x: number ): number {    
        return ( _x / ( 10 ** this.decimais ) ) ;
    }


    ////////////////////// INICIO EVENTOS E MENSAGENS

//TODO: tirar "FA" do início do nome do evento

    registraEventosAdicionaInvestidor(callback) {
        this.eventoPapeis = this.esgBndesTokenSmartContract.FA_InvestorAdded({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoPapeis.watch(callback);
    }

    registraEventosRegistrarInvestimento(callback) {
        console.log("web3-registraEventosRegistrarDoacao");
        this.eventoInvestimento = this.esgBndesTokenSmartContract.FA_InvestmentBooked({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoInvestimento.watch(callback);
    }

    registraEventosRecebimentoDoacao(callback) {
        console.log("web3-registraEventosRecebimentoDoacao");        
        this.eventoInvestimento = this.rbbTokenSmartContract.RBBTokenMintRequested({}, { fromBlock: 0, toBlock: 'latest' });
        this.eventoInvestimento.watch(callback);
    }


    registraEventosLiberacao(callback) {
//        this.eventoTransacao = this.bndesTokenSmartContract.Disbursement({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoTransacao.watch(callback);
    }
    registraEventosResgate(callback) {
//        this.eventoTransacao = this.bndesTokenSmartContract.RedemptionRequested({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoTransacao.watch(callback);
    }
    registraEventosLiquidacaoResgate(callback) {
//        this.eventoTransacao = this.bndesTokenSmartContract.RedemptionSettlement({}, { fromBlock: 0, toBlock: 'latest' });
//        this.eventoTransacao.watch(callback);
    }
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
            console.log("Watcher BNDESToken executando...")
            self.procuraTransacao(error, result, txHashProcurado, self, callback);
        });
        //TODO
        /*
        this.eventoBNDESRegistry = this.bndesRegistrySmartContract.allEvents( filtro );                 
        this.eventoBNDESRegistry.watch( function (error, result) {
            console.log("Watcher BNDESRegistry executando...")
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
        let self = this;

        return new Promise (function(resolve) {
            self.getRBBIDByCNPJ(cnpj, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO getRBBIDSync");
                reject(-1);
            });
        })
    }    

    getRBBIDByCNPJ(cnpj: number, fSuccess: any, fError: any): number {

        return this.rbbRegistrySmartContract.getIdFromCNPJ(cnpj, 
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }


    async getCNPJByAddressSync(addr: string) {
        let self = this;

        return new Promise (function(resolve) {
            self.getRegistryByAddress(addr, function(result) {
                let cnpj = result[1].c[0];
                resolve(cnpj);
            }, function(reject) {
                console.log("ERRO getCNPJByAddressSync");
                reject(-1);
            });
        })
    }    

    async getIdByAddressSync(addr: string) {
        let self = this;

        return new Promise (function(resolve) {
            self.getRegistryByAddress(addr, function(result) {
                let id = result[0].c[0];
                resolve(id);
            }, function(reject) {
                console.log("ERRO getIdByAddressSync");
                reject(-1);
            });
        })
    }    


    getRegistryByAddress(addr: string, fSuccess: any, fError: any): number {

        return this.rbbRegistrySmartContract.getRegistry(addr, 
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    ////////////////////// FIM REGISTRY

    ////////////////////// INICIO INVESTIDOR


    async associaInvestidor(rbbID: number, fSuccess: any, fError: any) {

        let contaBlockchain = await this.getCurrentAccountSync();   

        console.log("Web3Service - AssociaInvestidor");

        this.esgBndesTokenSmartContract.addInvestor(rbbID, 
            { from: contaBlockchain },
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    async registrarInvestimento(amount: number, fSuccess: any, fError: any) {

        let contaSelecionada = await this.getCurrentAccountSync();    
        
        console.log("Registra doacao");
        console.log("conta selecionada=" + contaSelecionada);
        
        amount = this.converteDecimalParaInteiro(amount);     
        console.log("Amount=" + amount);

        this.esgBndesTokenSmartContract.bookInvestment(amount, this.FAKE_HASH, { from: contaSelecionada },
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });        
        
    }


    getBookedBalanceOf(rbbId: number, fSuccess: any, fError: any): number {
        
        console.log("vai recuperar o balanceOf de " + rbbId);
        let self = this;
        return this.rbbTokenSmartContract.balanceRequestedTokens(1,rbbId,
            (error, valorSaldoCNPJ) => {
                if (error) fError(error);
                else fSuccess( self.converteInteiroParaDecimal( parseInt ( valorSaldoCNPJ ) ) );
            });
            
    }


    async receberDoacao(cnpj: string, amount: number, docHash: string, fSuccess: any, fError: any) {

        let contaSelecionada = await this.getCurrentAccountSync();    
        
        console.log("conta selecionada=" + contaSelecionada);
        console.log("Web3Service - ReceberDoacao");
        amount = this.converteDecimalParaInteiro(amount); 
        console.log("amount=" + amount);

        let contaBlockchain = await this.getContaBlockchainFromDoadorSync(cnpj);
        console.log("cnpj=" + cnpj);
        console.log("contaBlockchain=" + contaBlockchain);

        this.bndesTokenSmartContract.confirmDonation(contaBlockchain, amount, docHash, { from: contaSelecionada, gas: 500000 },
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });  
        
    } 

    public getContaBlockchainFromDoadorSync(cnpj:string) {
        let self = this;
        return new Promise(function(resolve, reject) {
            self.bndesRegistrySmartContract.getBlockchainAccountOfDonor(cnpj, function(error, result) {
                resolve(result);
            })
        })
    }    


    ////////////////////// FIM INVESTIDOR




    getConfirmedTotalSupply(fSuccess: any, fError: any): number {
        /*
        console.log("vai recuperar o confirmedtotalsupply. " );
        let self = this;
        return this.rbbTokenSmartContract.rbbBalances[]()
            (error, confirmedTotalSupply) => {
                if (error) fError(error);
                else fSuccess( self.converteInteiroParaDecimal(  parseInt ( confirmedTotalSupply ) ) );
            });
            */
           return 1;
    }


    getConfirmedBalanceOf(address: string, fSuccess: any, fError: any): number {
        /*
        console.log("vai recuperar o balanceOf de " + address);
        let self = this;
        return this.bndesTokenSmartContract.confirmedBalanceOf(address,
            (error, valorSaldoCNPJ) => {
                if (error) fError(error);
                else fSuccess( self.converteInteiroParaDecimal( parseInt ( valorSaldoCNPJ ) ) );
            });
            */
           return 1;

    }

    getDisbursementAddressBalance(fSuccess: any, fError: any): number {
        /*
        console.log("disbursementAddress");
        
        let self = this;
        return this.bndesTokenSmartContract.getDisbursementAddressBalance(
            (error, valorSaldo) => {
                if (error) fError(error);
                else fSuccess( self.converteInteiroParaDecimal( parseInt ( valorSaldo ) ) );
            });
            */
           return 1;
    }

    getPJInfo(addr: string, fSuccess: any, fError: any): number {
        let self = this;
        console.log("getPJInfo com addr=" + addr);
        console.log("bndesRegistrySmartContract=" + this.bndesRegistrySmartContract);
        return this.bndesRegistrySmartContract.getLegalEntityInfo(addr,
            (error, result) => {
                if (error) fError(error);
                else {
                    let pjInfo = self.montaPJInfo(result);
                    fSuccess(pjInfo);
                }
            });
    }


    isAccountEnabled(addr: string, fSuccess: any, fError: any): number {
        let self = this;
        return this.bndesRegistrySmartContract.isChangeAccountEnabled(addr,
            (error, result) => {
                if (error) fError(error);
                else {
                    fSuccess(result);
                }
            });
    }

    getPJInfoByCnpj(cnpj:string, idSubcredito: number, fSuccess: any, fError: any): number {
 
        let self = this;
        return this.bndesRegistrySmartContract.getLegalEntityInfoByCNPJ(cnpj, idSubcredito,
            (error, result) => {
                if (error) fError(error);
                else {
                    let pjInfo = self.montaPJInfo(result);
                    fSuccess(pjInfo);
                }
            });
    }

    getContaBlockchain(cnpj:string, idSubcredito: number, fSuccess: any, fError: any): string {
        return this.bndesRegistrySmartContract.getBlockchainAccount(cnpj, idSubcredito,
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    getAddressOwner(fSuccess: any, fError: any): number {
        return this.rbbTokenSmartContract.owner(
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }


    getDisbursementAddress(fSuccess: any, fError: any): string {
        
        return this.bndesTokenSmartContract.getDisbursementAddress(
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }



    async liberacao(target: string, transferAmount: number, fSuccess: any, fError: any) {
        console.log("Web3Service - Liberacao")

        let contaSelecionada = await this.getCurrentAccountSync();        
        transferAmount = this.converteDecimalParaInteiro(transferAmount);     
        console.log('target=' + target);
        console.log('TransferAmount(after)=' + transferAmount);

        this.bndesTokenSmartContract.makeDisbursement(target, transferAmount, { from: contaSelecionada, gas: 500000 },
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });        

    }




    async resgata(transferAmount: number, fSuccess: any, fError: any) {

        let contaSelecionada = await this.getCurrentAccountSync();    
        
        console.log("conta selecionada=" + contaSelecionada);
        console.log("Web3Service - Redeem");
        transferAmount = this.converteDecimalParaInteiro(transferAmount);     

        this.bndesTokenSmartContract.redeem(transferAmount, { from: contaSelecionada, gas: 500000 },
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

        this.bndesTokenSmartContract.notifyRedemptionSettlement(hashResgate, hashComprovante, 
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    async trocaAssociacaoDeConta(cnpj: number, idSubcredito: number, hashdeclaracao: string,
        fSuccess: any, fError: any) {

        console.log("Web3Service - Troca Associacao")
        console.log("CNPJ: " + cnpj + ", Contrato: " + idSubcredito + ", cnpj: " + cnpj)
        console.log("hash= " + hashdeclaracao);

        let contaBlockchain = await this.getCurrentAccountSync();    

        this.bndesTokenSmartContract.changeAccountLegalEntity(cnpj, idSubcredito, hashdeclaracao, 
            { from: contaBlockchain, gas: 500000 },
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    getBlockTimestamp(blockHash: number, fResult: any) {

        this.web3.eth.getBlock(blockHash, fResult);

    }


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
    

    isReservedAccount(address: string, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isReservedAccount(address,
            (error, result) => {
                if (error) fError(error);
                else fSuccess(result);
            });
    }

    isReservedAccountSync(address: string) {
        let self = this;

        return new Promise (function(resolve) {
            self.isReservedAccount(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO IS reserved account SYNC");
                reject(false);
            });
        })
    }    

    isResponsavelPorAssociarInvestidorSync (address: string) {
        let self = this;

        return new Promise (function(resolve) {
            self.isResponsavelPorAssociarInvestidor(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO isResponsavelPorAssociarInvestidorSync  SYNC");
                reject(false);
            });
        })        
    }

    isResponsavelPorAssociarInvestidor (address: string, fSuccess: any, fError: any): boolean {
        return this.esgBndesTokenSmartContract.owner(
            (error, ownerAddress) => {
                if (error) fError(error);
                else {
                    console.log("ownerAddress=" + ownerAddress);
                    fSuccess( address == ownerAddress);
                }
            });
    }


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

    isResponsibleForDonationConfirmation(address: string, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isResponsibleForDonationConfirmation(address,
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

    

    accountIsActive(address: string, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isValidatedAccount(address, 
        (error, result) => {
            if(error) fError(error);
            else fSuccess(result);
        });
    }

    async isSelectedAccountOwner() {
        let contaSelecionada = await this.getCurrentAccountSync();    
        return contaSelecionada == this.addressOwner;
    }

    isContaDisponivel(address: string, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isAvailableAccount(address, 
            (error, result) => {
                if(error) fError(error);
                else fSuccess(result);
            });
    }

    public isContaDisponivelSync(address: string) {
        
        let self = this;

        return new Promise (function(resolve) {
            self.isContaDisponivel(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO IS CONTA DISPONIVEL SYNC");
                reject(false);
            });
        })
    }


    isContaAguardandoValidacao(address: string, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isWaitingValidationAccount(address, 
            (error, result) => {
                if(error) fError(error);
                else fSuccess(result);
            });
    }

    public isContaAguardandoValidacaoSync(address: string) {
        
        let self = this;

        return new Promise (function(resolve) {
            self.isContaAguardandoValidacao(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO IS CONTA AGUARDANDO VALIDACAO SYNC");
                reject(false);
            });
        })
    }

    isContaValidada(address: string, fSuccess: any, fError: any): boolean {
        return this.bndesRegistrySmartContract.isValidatedAccount(address, 
            (error, result) => {
                if(error) fError(error);
                else fSuccess(result);
            });
    }

    public isContaValidadaSync(address: string) {
        
        let self = this;

        return new Promise (function(resolve) {
            self.isContaValidada(address, function(result) {
                resolve(result);
            }, function(reject) {
                console.log("ERRO IS CONTA VALIDADA SYNC");
                reject(false);
            });
        })
    }

    async habilitarCadastro(address: string, fSuccess: any, fError: any) {
        
        let contaBlockchain = await this.getCurrentAccountSync();    

        this.bndesRegistrySmartContract.enableChangeAccount(address,
            { from: contaBlockchain, gas: 500000 },
            (error, result) => {
                if(error) { fError(error); return false; }
                else { fSuccess(result); return true; }
            });
    }
    

    async validarCadastro(address: string, hashTentativa: string, fSuccess: any, fError: any) {
        
        let contaBlockchain = await this.getCurrentAccountSync();    

        this.bndesRegistrySmartContract.validateRegistryLegalEntity(address, hashTentativa, 
            { from: contaBlockchain, gas: 500000 },
            (error, result) => {
                if(error) { fError(error); return false; }
                else { fSuccess(result); return true; }
            });
    }

    async invalidarCadastro(address: string, fSuccess: any, fError: any) {

        let contaBlockchain = await this.getCurrentAccountSync();    

        this.bndesRegistrySmartContract.invalidateRegistryLegalEntity(address, 
            { from: contaBlockchain, gas: 500000 },
            (error, result) => {
                if(error) { fError(error); return false; }
                else { fSuccess(result); return true; }
            });
        return false;
    }

    

    getEstadoContaAsString(address: string, fSuccess: any, fError: any): string {
        let self = this;
        console.log("getEstadoContaAsString no web3:" + address);
        return this.bndesRegistrySmartContract.getAccountState(address, 
        (error, result) => {
            if(error) {
                console.log("Mensagem de erro ao chamar BNDESRegistry:");
                console.log(error);                
                fError(error);
            }
            else {
                console.log("Sucesso ao recuperar valor - getAccountState no web3:" + result);
                let str = self.getEstadoContaAsStringByCodigo (result);
                fSuccess(str);
            }   
        });
    }



    //Métodos de tradução back-front

    montaPJInfo(result): any {
        let pjInfo: any;

        console.log(result);
        pjInfo  = {};
        pjInfo.cnpj = result[0].c[0];
        pjInfo.idSubcredito = result[1].c[0];
        pjInfo.hashDeclaracao = result[2];
        pjInfo.status = result[3].c[0];
        pjInfo.address = result[4];

        pjInfo.statusAsString = this.getEstadoContaAsStringByCodigo(pjInfo.status);

        if (pjInfo.status == 2) {
            pjInfo.isValidada =  true;
        }
        else {
            pjInfo.isValidada = false;
        }


        if (pjInfo.status == 0) {
            pjInfo.isAssociavel =  true;
        }
        else {
            pjInfo.isAssociavel = false;
        }


        if (pjInfo.status == 1 || pjInfo.status == 2 || pjInfo.status == 3 || pjInfo.status == 4) {
            pjInfo.isTrocavel =  true;
        }
        else {
            pjInfo.isTrocavel = false;
        }


        return pjInfo;
    }


    getEstadoContaAsStringByCodigo(result): string {
        if (result==100) {
            return "Conta Reservada";
        }
        else if (result==0) {
            return "Disponível";
        }
        else if (result==1) {
            return "Aguardando validação do Cadastro";
        }                
        else if (result==2) {
            return "Validada";
        }    
        else if (result==3) {
            return "Conta invalidada pelo Validador";
        }    
        else if (result==4) {
            return "Conta invalidada por Troca de Conta";
        }                                                       
        else {
            return "N/A";
        }        
    }




    


}