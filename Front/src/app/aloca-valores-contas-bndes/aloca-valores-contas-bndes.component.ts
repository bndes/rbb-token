import { Component, OnInit, NgZone, ChangeDetectorRef } from '@angular/core';
//import {teste} from './teste';
import { FormsModule } from '@angular/forms';
import { Web3Service } from './../Web3Service';
import { HttpClient } from '@angular/common/http';
import { ConstantesService } from '../ConstantesService';
import { Router, ActivatedRoute } from '@angular/router';

import { PessoaJuridicaService } from '../pessoa-juridica.service';
import { BnAlertsService } from 'bndes-ux4';










@Component({
  selector: 'app-aloca-valores-contas-bndes',
  templateUrl: './aloca-valores-contas-bndes.component.html',
  styleUrls: ['./aloca-valores-contas-bndes.component.css']
})
export class AlocaValoresContasBndesComponent implements OnInit {

  selectedAccount: any;

disponivelParaAlocacao: any = "";  
ValorA_Alocar: any = "";
  SaldoAtual: any = ""
  
  constructor(private http: HttpClient, private constantes: ConstantesService,private pessoaJuridicaService: PessoaJuridicaService, protected bnAlertsService: BnAlertsService,
    private web3Service: Web3Service, private router: Router, private zone: NgZone, private ref: ChangeDetectorRef) { 
    
    

    let self = this;
      setInterval(function () {
        self.recuperaContaSelecionada(), 1000});
    
  }
  async ngOnInit() {
  }

  async onSubmit(){
    let idConta = await this.web3Service.getIdByAddressSync( await this.web3Service.getCurrentAccountSync());
    let verificadoDeMudanca1=this.disponivelParaAlocacao;
    let verificadoDeMudanca2=this.SaldoAtual;
//TODO: FALAR LEO
    //    await this.web3Service.alocaRecursosDesembolso(idConta,<number>(this.ValorA_Alocar));
    
    this.SaldoAtual = await this.web3Service.getDisbursementBalance();
    this.disponivelParaAlocacao = await this.web3Service.getMintedBalance();
    while(verificadoDeMudanca1 == this.disponivelParaAlocacao){
      this.disponivelParaAlocacao = await this.web3Service.getMintedBalance();
    }
    while(verificadoDeMudanca2 == this.SaldoAtual){
      this.SaldoAtual = await this.web3Service.getDisbursementBalance();
    }

  }

  
 

  async recuperaContaSelecionada() {

    let self = this;
    
    let newSelectedAccount = await this.web3Service.getCurrentAccountSync();
  
    if ( !self.selectedAccount || (newSelectedAccount !== self.selectedAccount && newSelectedAccount)) {
  
      this.selectedAccount = newSelectedAccount;
      console.log("selectedAccount=" + this.selectedAccount);
      self.recuperaSaldoBNDESToken();
      
    }
  
  }  
  
   async recuperaSaldoBNDESToken() {
  
    this.disponivelParaAlocacao = await this.web3Service.getMintedBalance();
    this.SaldoAtual = await this.web3Service.getDisbursementBalance();
    
  }
  
 

}
