import { Routes, Route, Navigate } from 'react-router-dom';
import { PageLayout } from '@/components/PageLayout';
import { SupplierList } from '@/pages/SupplierList';
import { SupplierProfile } from '@/pages/SupplierProfile';
import { ErrorBoundary } from '@/components/ErrorBoundary';

export default function App() {
  return (
    <ErrorBoundary>
      <Routes>
        <Route element={<PageLayout />}>
          <Route path="/" element={<Navigate to="/suppliers" replace />} />
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
