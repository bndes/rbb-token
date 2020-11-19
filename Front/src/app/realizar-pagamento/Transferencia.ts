export class Transferencia {
  rbbId: number;

  contaBlockchainOrigem: string;
    numeroSubcreditoSelecionado: number;

    subcreditos: Subcredito[];
    saldoOrigem: number;
  
    papelEmpresaDestino: string;
    cnpjDestino: string;
    contaBlockchainDestino: string;
    razaoSocialDestino: string;
    msgEmpresaDestino: string;
  
    valorTransferencia: number;
    hashOperacao: string;
  
    dataHora: Date;
  }

  export class Subcredito {
    numero: number;
  }