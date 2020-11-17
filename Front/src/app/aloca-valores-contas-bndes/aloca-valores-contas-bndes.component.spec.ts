import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { AlocaValoresContasBndesComponent } from './aloca-valores-contas-bndes.component';

describe('AlocaValoresContasBndesComponent', () => {
  let component: AlocaValoresContasBndesComponent;
  let fixture: ComponentFixture<AlocaValoresContasBndesComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ AlocaValoresContasBndesComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(AlocaValoresContasBndesComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
