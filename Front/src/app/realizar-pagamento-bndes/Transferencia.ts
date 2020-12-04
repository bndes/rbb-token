export class Transferencia {

  contaBlockchainOrigem: string;

    cnpjOrigem: string;
    numeroSubcreditoSelecionado: number;
    subcreditos: Subcredito[];
    saldoOrigem: number;
    rbbIdOrigem: number;
  
//    papelEmpresaDestino: string;
    cnpjDestino: string;
    cnpjDestinoWithMask: string;
    contaBlockchainDestino: string;
    razaoSocialDestino: string;
    rbbIdDestino: number;

//    msgEmpresaDestino: string;
  
    valorTransferencia: number;
    hashOperacao: string;
  
    dataHora: Date;
  }

  export class Subcredito {
    numero: number;
  }