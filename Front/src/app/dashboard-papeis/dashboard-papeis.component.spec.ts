import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { DashboardPapeisComponent } from './dashboard-papeis.component';

describe('DashboardPapeisComponent', () => {
  let component: DashboardPapeisComponent;
  let fixture: ComponentFixture<DashboardPapeisComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ DashboardPapeisComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(DashboardPapeisComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
