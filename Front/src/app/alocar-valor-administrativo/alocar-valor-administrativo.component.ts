
import { Component, OnInit, NgZone, ChangeDetectorRef } from '@angular/core';
//import {teste} from './teste';
import { FormsModule } from '@angular/forms';
import { Web3Service } from './../Web3Service';
import { HttpClient } from '@angular/common/http';
import { ConstantesService } from '../ConstantesService';
import { Router, ActivatedRoute } from '@angular/router';

import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { BnAlertsService } from 'bndes-ux4';
import { Alocacao, Subcredito } from './Alocacao';

import { Utils } from '../shared/utils';


@Component({
  selector: 'app-alocar-valor-administrativo',
  templateUrl: './alocar-valor-administrativo.component.html',
  styleUrls: ['./alocar-valor-administrativo.component.css']
})
export class AlocarValorAdministrativoComponent implements OnInit {
  selectedAccount: any;
  //SaldoAtual:any=0 ;
  //ValorASerAlocado:any=0;
  alocacao: Alocacao; 
  maskCnpj: any;

  constructor(private http: HttpClient, private constantes: ConstantesService,private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService,
    private web3Service: Web3Service, private router: Router, private zone: NgZone, private ref: ChangeDetectorRef) { 



    let self = this;
      setInterval(function () {
        self.recuperaContaSelecionada(), 1000});
  }

  ngOnInit() {
    this.maskCnpj = Utils.getMaskCnpj();     
    this.alocacao = new Alocacao();
    this.inicializaAlocacao();
    this.recuperaSaldoBNDESToken();
  }

  inicializaAlocacao() {
    this.alocacao.saldoAtual = 0;
    this.alocacao.valorA_Alocar=0;
    this.alocacao.disponivelParaAlocacao=0;
    
  }


 

  async recuperaContaSelecionada() {

    let self = this;
    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
  
    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {
  
      this.selectedAccount = newSelectedAccount;
      console.log("selectedAccount=" + this.selectedAccount);

      if (!(await this.web3Service.isResponsibleForInitialAllocation())) {
        let s = "essa conta nao é responsavel pela Alocação";
        this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
        return;
      }

      self.recuperaSaldoBNDESToken();
      
    }
  
  }  
  
   async recuperaSaldoBNDESToken() {
    this.alocacao.saldoAtual=  await this.web3Service.getAdminFeeBalance();
    this.alocacao.disponivelParaAlocacao=await this.web3Service.getMintedBalance();
    
    
  }
  
  async alocarValor(){
    let self = this;
    if (!(await this.web3Service.isResponsibleForInitialAllocation())) {
      let s = "essa conta nao é responsavel pela Alocação";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }
    
    if(this.alocacao.disponivelParaAlocacao < this.alocacao.valorA_Alocar){
      let s = "Valor a alocar maior que o valor disponivel";
      this.bnAlertsService.criarAlerta("error", "Erro", s, 5);
      return;
    }



    let idConta = await this.web3Service.getIdByAddressSync( await this.web3Service.getCurrentAccountSync());

    
    
    await this.web3Service.alocaRecursosDesembolso2(idConta,<number>(this.alocacao.valorA_Alocar)).then(
      
      function(txHash) { 
        
        self.alocacao.hashID = txHash;

        Utils.criarAlertasAvisoConfirmacao( txHash, 
                                            self.web3Service, 
                                            self.bnAlertsService, 
                                            "A alocação está sendo enviada para a blockchain.", 
                                            "A alocação foi confirmada na blockchain.", 
                                            self.zone) 
        self.router.navigate(['sociedade/dash-transf']);                                                          
  
      },
      function(error) {  
        Utils.criarAlertaErro( self.bnAlertsService, 
          "Erro ao liberar na blockchain. Uma possibilidade é a conta selecionada não ser a do BNDES", 
          error )  
  });    


  Utils.criarAlertaAcaoUsuario( self.bnAlertsService, 
                                "Confirme a operação no metamask e aguarde a confirmação da liberação." );
    





    /*
    this.SaldoAtual = await this.web3Service.getAdminFeeBalance();
    
    
    while(verificadoDeMudanca == this.SaldoAtual){
      this.SaldoAtual = await this.web3Service.getAdminFeeBalance();
    }
    */
  }





}
