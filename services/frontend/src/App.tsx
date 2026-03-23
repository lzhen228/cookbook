import { Routes, Route, Navigate } from 'react-router-dom';
import { PageLayout } from '@/components/PageLayout';
import { Dashboard } from '@/pages/Dashboard';
import { AlertCenter } from '@/pages/AlertCenter';
import { SupplierList } from '@/pages/SupplierList';
import { SupplierProfile } from '@/pages/SupplierProfile';
import { ErrorBoundary } from '@/components/ErrorBoundary';

export default function App() {
  return (
    <ErrorBoundary>
      <Routes>
        <Route element={<PageLayout />}>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route
            path="/dashboard"
            element={
              <ErrorBoundary>
                <Dashboard />
              </ErrorBoundary>
            }
          />
          <Route
            path="/risk-events"
            element={
              <ErrorBoundary>
                <AlertCenter />
              </ErrorBoundary>
            }
          />
          <Route
            path="/suppliers"
            element={
              <ErrorBoundary>
                <SupplierList />
              </ErrorBoundary>
            }
          />
          <Route
            path="/suppliers/:id"
            element={
              <ErrorBoundary>
                <SupplierProfile />
              </ErrorBoundary>
            }
          />
        </Route>
      </Routes>
    </ErrorBoundary>
  );
}
